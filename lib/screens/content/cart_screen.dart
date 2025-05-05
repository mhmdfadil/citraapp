import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/screens/content/chat.dart';
import '/screens/content/checkout.dart';
import '/screens/user_screen.dart';

class CartContent extends StatefulWidget {
  const CartContent({super.key});

  @override
  State<CartContent> createState() => _CartContentState();
}

class _CartContentState extends State<CartContent> {
  bool selectAll = false;
  List<CartItem> items = [];
  double totalPrice = 0;
  int totalItems = 0;
  final supabase = Supabase.instance.client;
  String? userId;
  bool isLoading = true;
  String? errorMessage;
  Map<int, bool> editMode = {}; // Untuk menyimpan status edit per item

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUserId = prefs.getString('user_id');

      if (savedUserId != null) {
        setState(() {
          userId = savedUserId;
        });
        await _fetchCartItems();
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Gagal memuat ID pengguna: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<void> _fetchCartItems() async {
    if (userId == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final response = await supabase
          .from('carts')
          .select('''
            id, 
            count, 
            user_id, 
            product_id, 
            products:product_id (id, name, price_display, photos, categories!inner(id, name))
          ''')
          .eq('user_id', userId!)
          .order('created_at', ascending: false);

      if (response.isEmpty) {
        setState(() {
          items = [];
          isLoading = false;
        });
        return;
      }

      final List<CartItem> loadedItems = [];
      for (var item in response) {
        try {
          final product = item['products'] as Map<String, dynamic>? ?? {};
          final category = product['categories'] as Map<String, dynamic>? ?? {};

          // Handle photos which might be a List or a String
          dynamic photos = product['photos'];
          String firstPhotoUrl = '';
          if (photos is List && photos.isNotEmpty) {
            firstPhotoUrl = photos[0] as String;
          } else if (photos is String) {
            firstPhotoUrl = photos;
          }

          loadedItems.add(CartItem(
            id: item['id'] as int,
            product_id: item['product_id'] as int,
            category: category['name']?.toString() ?? 'No Category',
            name: product['name']?.toString() ?? 'No Name',
            price: (product['price_display']?.toString() ?? '0').replaceAll(RegExp(r'[^0-9.]'), ''),
            imageUrl: firstPhotoUrl.isNotEmpty
                ? supabase.storage.from('picture-products').getPublicUrl(firstPhotoUrl)
                : '',
            count: (item['count'] as num?)?.toInt() ?? 1,
            isSelected: false,
          ));
        } catch (e) {
          debugPrint('Error processing cart item: $e');
        }
      }

      setState(() {
        items = loadedItems;
        totalItems = items.length; // Jumlah item unik di keranjang
        editMode = {for (var item in items) item.id: false}; // Inisialisasi edit mode
        _calculateTotal();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Gagal memuat keranjang: ${e.toString()}';
        isLoading = false;
      });
      debugPrint('Error fetching cart items: $e');
    }
  }

  void _calculateTotal() {
    double newTotal = 0;
    for (var item in items) {
      if (item.isSelected) {
        final price = double.tryParse(item.price) ?? 0;
        newTotal += price * item.count;
      }
    }
    setState(() {
      totalPrice = newTotal;
    });
  }

  Future<void> _updateCartItemCount(int cartId, int newCount) async {
    if (newCount < 1) return;

    try {
      await supabase
          .from('carts')
          .update({'count': newCount})
          .eq('id', cartId);

      setState(() {
        final index = items.indexWhere((item) => item.id == cartId);
        if (index != -1) {
          items[index].count = newCount;
          _calculateTotal();
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengupdate jumlah: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deleteCartItem(int cartId) async {
    try {
      await supabase
          .from('carts')
          .delete()
          .eq('id', cartId);

      setState(() {
        items.removeWhere((item) => item.id == cartId);
        totalItems = items.length;
        editMode.remove(cartId);
        _calculateTotal();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus item: ${e.toString()}')),
        );
      }
    }
  }

  void _toggleEditMode(int cartId) {
    setState(() {
      editMode[cartId] = !(editMode[cartId] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 243, 207, 242),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF273F0),
        leading: GestureDetector(
           onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserScreen()),
    );
  },
          child: Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                FontAwesomeIcons.arrowLeft,
                color: Colors.black,
                size: 18,
              ),
            ),
          ),
        ),
        title: Text(
          'Keranjang Saya ($totalItems)',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              FontAwesomeIcons.commentDots,
              color: Colors.black,
              size: 28,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatPage()),
              );
            },
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: items.isEmpty ? null : _buildBottomNavigationBar(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (errorMessage != null) {
      return Center(
        child: Text(
          errorMessage!,
          style: const TextStyle(fontSize: 18, color: Colors.red),
        ),
      );
    }
    
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Keranjang belanja kosong',
          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _fetchCartItems,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: items.map((item) => _buildCartItem(item)).toList(),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
  return Container(
    height: 100,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Colors.grey[400]!)),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        // For smaller screens, we'll adjust the layout
        bool isSmallScreen = constraints.maxWidth < 600;
        
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Checkbox and "Semua" text
            Row(
              children: [
                Container(
                   width: 20,
    height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Checkbox(
                    value: selectAll,
                    onChanged: (value) {
                      setState(() {
                        selectAll = value!;
                        for (var item in items) {
                          item.isSelected = selectAll;
                        }
                        _calculateTotal();
                      });
                    },
                    activeColor: Colors.black,
                    checkColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: const BorderSide(color: Colors.black, width: 2),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Semua',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            
            // Total and Checkout button - now in one flexible row
            Flexible(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Total price
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        const Text(
                          'Total ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          'Rp ${totalPrice.toStringAsFixed(0).replaceAllMapped(
                            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                            (Match m) => '${m[1]}.',
                          )}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF1E00),
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  
                  // Checkout button - adjusted for small screens
                  SizedBox(
                    width: isSmallScreen ? null : 200, // Flexible width on small screens
                    child: ElevatedButton(
  onPressed: () {
    final selectedItems = items.where((item) => item.isSelected).toList();
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih setidaknya satu item untuk checkout')),
      );
      return;
    }
    
    // Calculate total items count (sum of quantities)
    int totalItemsCount = selectedItems.fold(0, (sum, item) => sum + item.count);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutPage(
          cartItems: selectedItems,
          totalPrice: totalPrice, // Pass the calculated total price
          totalItems: totalItemsCount, // Pass the total quantity of items
        ),
      ),
    );
  },
  style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFFFF1E00),
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    padding: EdgeInsets.symmetric(
      horizontal: isSmallScreen ? 18 : 40,
      vertical: isSmallScreen ? 14 : 18,
    ),
    elevation: 4,
  ),
  child: Text(
    'Checkout',
    style: TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: isSmallScreen ? 16 : 18,
    ),
  ),
),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

  Widget _buildCartItem(CartItem item) {
  final priceValue = double.tryParse(item.price) ?? 0;
  final itemTotal = priceValue * item.count;
  final isEditing = editMode[item.id] ?? false;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            // Checkbox
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[300],
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: item.isSelected,
                  onChanged: (value) {
                    setState(() {
                      item.isSelected = value!;
                      selectAll = items.every((item) => item.isSelected);
                      _calculateTotal();
                    });
                  },
                  activeColor: Colors.black,
                  checkColor: Colors.white,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              item.category,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontSize: 21,
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => _toggleEditMode(item.id),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[300],
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: Text(
                isEditing ? 'Selesai' : 'Ubah',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
      const SizedBox(height: 4),
      Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Padding(
              padding: const EdgeInsets.all(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  color: Colors.white.withOpacity(0.5),
                  width: 140,
                  height: 140,
                  child: item.imageUrl.isNotEmpty
                      ? Image.network(
                          item.imageUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.error_outline, color: Colors.red),
                        )
                      : const Icon(Icons.image_not_supported),
                ),
              ),
            ),
            // Product Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Price
                    Text(
                      'Rp ${priceValue.toStringAsFixed(0).replaceAllMapped(
                        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                        (Match m) => '${m[1]}.',
                      )}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF1E00),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Total Price
                    Text(
                      'Total: Rp ${itemTotal.toStringAsFixed(0).replaceAllMapped(
                        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                        (Match m) => '${m[1]}.',
                      )}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Quantity Controls or Count
                    Row(
                      children: [
                        Text(
                          'Jumlah: ',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (!isEditing) ...[
                          Text(
                            '${item.count}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        if (isEditing) ...[
                          IconButton(
                            icon: const Icon(Icons.remove, size: 20),
                            onPressed: () {
                              if (item.count > 1) {
                                _updateCartItemCount(item.id, item.count - 1);
                              }
                            },
                          ),
                          Text(
                            '${item.count}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 20),
                            onPressed: () {
                              _updateCartItemCount(item.id, item.count + 1);
                            },
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Delete Button (only in edit mode)
            if (isEditing)
              Padding(
                padding: const EdgeInsets.only(top: 110, right: 8),
                child: ElevatedButton(
                  onPressed: () => _showDeleteConfirmationDialog(item.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: const Color(0xFFFF1E00),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                  ),
                  child: const Text(
                    'Hapus',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
    ],
  );
}
  void _showDeleteConfirmationDialog(int cartId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text('Yakin ingin menghapus item ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteCartItem(cartId);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class CartItem {
  final int id;
  final int product_id;
  final String category;
  final String name;
  final String price;
  final String imageUrl;
  int count;
  bool isSelected;

  CartItem({
    required this.id,
    required this.product_id,
    required this.category,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.count,
    required this.isSelected,
  });

  get quantity => null;
}