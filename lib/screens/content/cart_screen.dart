import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/screens/content/chat.dart';
import '/screens/content/checkout.dart';
import '/screens/user_screen.dart';
import 'package:citraapp/screens/content/product_detail_page.dart';

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
  Map<int, bool> editMode = {};
  Map<int, int> productStocks = {}; // To store product stock information

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

      // First fetch the cart items with product information
      final response = await supabase
          .from('carts')
          .select('''
            id, 
            count, 
            user_id, 
            product_id, 
            products:product_id (id, name, price_display, stock, categories!inner(id, name))
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
      final Map<int, int> stocks = {};
      
      // Fetch photos for all products in one query
      final productIds = response.map<String>((item) {
        final product = item['products'] as Map<String, dynamic>? ?? {};
        return product['id'].toString();
      }).toList();

      final photosResponse = await supabase
          .from('photo_items')
          .select('id, name, product_id')
          .in_('product_id', productIds)
          .order('created_at', ascending: true);

      // Create a map of product_id to its first photo
      final Map<int, String> productPhotos = {};
      for (var photo in photosResponse) {
        final productId = photo['product_id'] as int;
        if (!productPhotos.containsKey(productId)) {
          productPhotos[productId] = photo['name'] as String;
        }
      }

      for (var item in response) {
        try {
          final product = item['products'] as Map<String, dynamic>? ?? {};
          final category = product['categories'] as Map<String, dynamic>? ?? {};
          final productId = product['id'] as int? ?? 0;
          final stock = (product['stock'] as num?)?.toInt() ?? 0;

          // Store product stock
          stocks[productId] = stock;

          // Get the photo URL from our photos map
          String firstPhotoUrl = productPhotos[productId] ?? '';

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
        productStocks = stocks;
        totalItems = items.length;
        editMode = {for (var item in items) item.id: false};
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
      // Get the product ID and current count
      final item = items.firstWhere((item) => item.id == cartId);
      final productId = item.product_id;
      final currentCount = item.count;
      
      // Check stock availability
      final stock = productStocks[productId] ?? 0;
      if (newCount > stock) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Stok tidak mencukupi. Stok tersedia: $stock')),
          );
        }
        return;
      }

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
    // Check if any selected item has stock = 0
    bool hasOutOfStockSelectedItems = items.any((item) => 
        item.isSelected && (productStocks[item.product_id] ?? 0) <= 0);

    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[400]!)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool isSmallScreen = constraints.maxWidth < 600;
          
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
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
              
              Flexible(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
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
                    
                    SizedBox(
                      width: isSmallScreen ? null : 200,
                      child: ElevatedButton(
                        onPressed: hasOutOfStockSelectedItems ? null : () {
                          final selectedItems = items.where((item) => item.isSelected).toList();
                          if (selectedItems.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Pilih setidaknya satu item untuk checkout')),
                            );
                            return;
                          }
                          
                          int totalItemsCount = selectedItems.fold(0, (sum, item) => sum + item.count);
                          
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CheckoutPage(
                                cartItems: selectedItems,
                                totalPrice: totalPrice,
                                totalItems: totalItemsCount,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasOutOfStockSelectedItems 
                              ? Colors.grey 
                              : const Color(0xFFFF1E00),
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
  final stock = productStocks[item.product_id] ?? 0;

  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          spreadRadius: 1,
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: Column(
      children: [
        // Header with checkbox, category and edit button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              SizedBox(
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
                  checkColor: Colors.grey,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.category,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => _toggleEditMode(item.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                ),
                child: Text(
                  isEditing ? 'Selesai' : 'Ubah',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Product content - Make this row clickable
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductDetailPage(productId: item.product_id.toString()),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    color: Colors.grey[100],
                    width: 100,
                    height: 100,
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
                                Image.asset(
                                  'assets/images/placeholder.png',
                                  fit: BoxFit.cover,
                                ),
                          )
                        : Image.asset(
                            'assets/images/placeholder.png',
                            fit: BoxFit.cover,
                        ),
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Product details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product name with fixed height
                      SizedBox(
                        height: 40, // Fixed height for name
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // Price row
                      SizedBox(
                        height: 20, // Fixed height for price
                        child: Text(
                          'Rp ${priceValue.toStringAsFixed(0).replaceAllMapped(
                            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                            (Match m) => '${m[1]}.',
                          )}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFF1E00),
                            fontSize: 16,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // Total price row
                      SizedBox(
                        height: 20, // Fixed height for total price
                        child: Text(
                          'Total: Rp ${itemTotal.toStringAsFixed(0).replaceAllMapped(
                            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                            (Match m) => '${m[1]}.',
                          )}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // Quantity controls and stock info
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Stock information
                          Text(
                            'Stok: $stock',
                            style: TextStyle(
                              fontSize: 12,
                              color: stock > 0 ? Colors.grey[600] : Colors.red,
                            ),
                          ),
                          
                          const SizedBox(height: 4),
                          
                          // Quantity controls
                          Row(
                            children: [
                              const Text(
                                'Jumlah: ',
                                style: TextStyle(fontSize: 14),
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
                                  icon: const Icon(Icons.remove, size: 18),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    if (item.count > 1) {
                                      _updateCartItemCount(item.id, item.count - 1);
                                    }
                                  },
                                ),
                                Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${item.count}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add, size: 18),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    if (item.count < stock) {
                                      _updateCartItemCount(item.id, item.count + 1);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Stok maksimum $stock telah tercapai')),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Delete button (only in edit mode)
        if (isEditing)
          Padding(
            padding: const EdgeInsets.only(bottom: 12, right: 12),
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 150, // Fixed width
                child: ElevatedButton(
                  onPressed: () => _showDeleteConfirmationDialog(item.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text(
                    'Hapus',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
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
}