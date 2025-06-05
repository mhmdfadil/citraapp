import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:citraapp/screens/content/cart_screen.dart';
import 'package:citraapp/screens/content/chat.dart';
import 'package:citraapp/screens/content/co_buy.dart';
import 'package:citraapp/screens/content/card_product.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:citraapp/login.dart';



class ProductDetailPage extends StatefulWidget {
  final String productId;

  const ProductDetailPage({Key? key, required this.productId}) : super(key: key);

  @override
  _ProductDetailPageState createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  Map<String, dynamic>? _product;
  bool _isLoading = true;
  bool _isFavorite = false;
  int _cartItemCount = 0;
  bool _isCheckingFavorite = false;
  int _availableStock = 0;
  bool _showFullImage = false;
  int _currentImageIndex = 0;
  List<Map<String, dynamic>> _photoItems = [];
   String _categoryName = ''; // Added to store category name

  @override
  void initState() {
    super.initState();
    _fetchProduct();
    _fetchCartCount();
    _checkFavoriteStatus();
    _fetchPhotoItems();
  }

  Future<void> _fetchPhotoItems() async {
    try {
      final response = await _supabase
          .from('photo_items')
          .select('id, name')
          .eq('product_id', widget.productId)
          .order('id', ascending: true);

      setState(() {
        _photoItems = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error fetching photo items: $e');
    }
  }

  Future<void> _fetchProduct() async {
    try {
      // Modified query to join with categories table
      final response = await _supabase
          .from('products')
          .select('''
            *, 
            categories:category_id (name)
          ''')
          .eq('id', widget.productId)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _product = response;
          _availableStock = response['stock'] ?? 0;
          // Get category name from the joined table
          _categoryName = (response['categories'] as Map<String, dynamic>?)?['name'] ?? '';
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Produk tidak ditemukan')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      print('Error fetching product: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memuat produk')),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchCartCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId != null) {
        final response = await _supabase
            .from('carts')
            .select('id')
            .eq('user_id', userId);

        setState(() => _cartItemCount = response.length);
      }
    } catch (e) {
      print('Error fetching cart count: $e');
    }
  }

  Future<void> _checkFavoriteStatus() async {
    try {
      setState(() => _isCheckingFavorite = true);
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId != null) {
        final response = await _supabase
            .from('favorites')
            .select()
            .eq('user_id', userId)
            .eq('product_id', widget.productId)
            .maybeSingle();

        setState(() => _isFavorite = response != null);
      }
    } catch (e) {
      print('Error checking favorite status: $e');
    } finally {
      if (mounted) {
        setState(() => _isCheckingFavorite = false);
      }
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      
      if (userId == null) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginPage()),
          );
        }
        return;
      }

      if (_isFavorite) {
        await _supabase
            .from('favorites')
            .delete()
            .eq('user_id', userId)
            .eq('product_id', widget.productId);
      } else {
        await _supabase.from('favorites').insert({
          'user_id': userId,
          'product_id': widget.productId,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      setState(() => _isFavorite = !_isFavorite);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isFavorite 
            ? 'Produk ditambahkan ke favorit' 
            : 'Produk dihapus dari favorit')),
        );
      }
    } catch (e) {
      print('Error toggling favorite: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memperbarui favorit')),
        );
      }
    }
  }

  String _formatSoldCount(int sold) {
  if (sold < 1000) {
    return sold.toString();
  } else if (sold < 10000) {
    double thousands = sold / 1000;
    return thousands.toStringAsFixed(thousands % 1 == 0 ? 0 : 1) + ' K+';
  } else if (sold < 1000000) {
    double thousands = sold / 1000;
    return thousands.toStringAsFixed(thousands % 1 == 0 ? 0 : 1) + ' K+';
  } else {
    double millions = sold / 1000000;
    return millions.toStringAsFixed(millions % 1 == 0 ? 0 : 1) + ' JT+';
  }
}

String _formatPrice(int price) {
  return price.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]}.',
  );
}

  Future<void> _addToCart() async {
    try {
      if (_product == null || _availableStock <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Stok produk habis')),
          );
        }
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      
      if (userId == null) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginPage()),
          );
        }
        return;
      }

      final existingCart = await _supabase
          .from('carts')
          .select()
          .eq('product_id', widget.productId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingCart != null) {
        if (existingCart['count'] >= _availableStock) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Stok tersedia hanya $_availableStock')),
            );
          }
          return;
        }
        
        await _supabase
            .from('carts')
            .update({'count': existingCart['count'] + 1})
            .eq('id', existingCart['id']);
      } else {
        await _supabase.from('carts').insert({
          'product_id': widget.productId,
          'user_id': userId,
          'count': 1,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      await _fetchCartCount();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produk berhasil ditambahkan ke keranjang')),
        );
      }
    } catch (e) {
      print('Error adding to cart: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menambahkan ke keranjang')),
        );
      }
    }
  }

  void _buyNow() {
    if (_product == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produk tidak tersedia')),
        );
      }
      return;
    }
    
    if (_availableStock <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stok produk habis')),
        );
      }
      return;
    }

    final price = double.tryParse(_product!['price_display']?.toString().replaceAll('.', '') ?? '0') ?? 0;
    final quantity = 1;
    final totalPrice = price * quantity;
    final totalCount = quantity;

    // Use the first photo as the imageUrl
    final imageUrl = _photoItems.isNotEmpty 
        ? _supabase.storage.from('picture-products').getPublicUrl(_photoItems[0]['name'])
        : '';

    final cardproduct = CardProduct(
      id: DateTime.now().millisecondsSinceEpoch,
      product_id: int.tryParse(widget.productId) ?? 0,
      category: _categoryName,
      name: _product!['name']?.toString() ?? 'No Name',
      price: _product!['price_display']?.toString() ?? '0',
      imageUrl: imageUrl,
      quantity: quantity,
      isSelected: true,
      stock: _availableStock,
    );

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => COBuyPage(
            cartItems: [cardproduct],
            totalItems: totalCount,
            totalPrice: totalPrice,
          ),
        ),
      );
    }
  }

  void _showImagePreview(int index) {
    setState(() {
      _currentImageIndex = index;
      _showFullImage = true;
    });
  }

  void _hideImagePreview() {
    setState(() {
      _showFullImage = false;
    });
  }

  void _changeImage(int newIndex) {
    setState(() {
      _currentImageIndex = newIndex;
    });
  }

  Widget _buildImageGallery() {
    if (_photoItems.isEmpty) {
      return Image.asset(
        'assets/images/placeholder.png',
        fit: BoxFit.cover,
      );
    }

    return Column(
      children: [
        // Main image display
        GestureDetector(
          onTap: () => _showImagePreview(_currentImageIndex),
          child: SizedBox(
            height: 300,
            width: double.infinity,
            child: Image.network(
              _supabase.storage.from('picture-products').getPublicUrl(_photoItems[_currentImageIndex]['name']),
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => 
                Image.asset(
                  'assets/images/placeholder.png',
                  fit: BoxFit.cover,
                ),
            ),
          ),
        ),
        
      if (_photoItems.length > 1)
  Container(
    height: 70,  // Tinggi sedikit ditambah
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Center(
      child: ListView.builder(
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        itemCount: _photoItems.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _changeImage(index),
            child: Container(
              width: 50,  // Lebar thumbnail ditambah
              margin: const EdgeInsets.symmetric(horizontal: 5),  // Jarak antar thumbnail diperbesar
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),  // Background semi-transparan
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _currentImageIndex == index 
                      ? const Color(0xFFF273F0)  // Pink saat aktif
                      : Colors.grey.shade300,   // Abu-abu saat tidak aktif
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),  // Padding dalam thumbnail
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    _supabase.storage.from('picture-products').getPublicUrl(_photoItems[index]['name']),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => 
                      Image.asset(
                        'assets/images/placeholder.png',
                        fit: BoxFit.cover,
                      ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  ),
      ],
    );
  }

  Widget _buildFullImagePreview() {
    return GestureDetector(
      onTap: _hideImagePreview,
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! > 0) {
          // Swipe right to left (next)
          if (_currentImageIndex > 0) {
            _changeImage(_currentImageIndex - 1);
          }
        } else if (details.primaryVelocity! < 0) {
          // Swipe left to right (previous)
          if (_currentImageIndex < _photoItems.length - 1) {
            _changeImage(_currentImageIndex + 1);
          }
        }
      },
      child: Container(
        color: Colors.black.withOpacity(0.9),
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        child: Stack(
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: _photoItems.isNotEmpty
                    ? Image.network(
                        _supabase.storage.from('picture-products').getPublicUrl(_photoItems[_currentImageIndex]['name']),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Image.asset(
                          'assets/images/placeholder.png',
                          fit: BoxFit.contain,
                        ),
                      )
                    : Image.asset(
                        'assets/images/placeholder.png',
                        fit: BoxFit.contain,
                      ),
              ),
            ),
            Positioned(
              top: 20,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: _hideImagePreview,
              ),
            ),
            if (_photoItems.length > 1)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_photoItems.length, (index) {
                    return Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentImageIndex == index 
                            ? Colors.white 
                            : Colors.white.withOpacity(0.5),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFFF273F0),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_product == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFFF273F0),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: Text('Produk tidak ditemukan')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF273F0),
        elevation: 0,
        toolbarHeight: 80,
        leading: Container(
          margin: const EdgeInsets.only(left: 20, top: 15, bottom: 15),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(50),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
            padding: const EdgeInsets.all(8),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(top: 15, bottom: 15, right: 10),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(50),
            ),
            child: IconButton(
              icon: const Icon(Icons.share, color: Colors.black, size: 20),
              padding: const EdgeInsets.all(8),
              onPressed: () async {
                final deeplinkUrl = 'https://citra-cosmetic.github.io/app_flutter/deeplink.html?product/${_product!['id']}';
                await Share.share(
                  'Lihat produk "${_product!['name']}" di Citra Cosmetic:\n$deeplinkUrl',
                );
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 15, bottom: 15, right: 20),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(50),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart, color: Colors.black, size: 20),
                  padding: const EdgeInsets.all(8),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CartContent()),
                    ).then((_) => _fetchCartCount());
                  },
                ),
                if (_cartItemCount > 0)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        _cartItemCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 15, bottom: 15, right: 20),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(50),
            ),
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.black, size: 20),
              offset: const Offset(0, 45),
              onSelected: (value) {
                if (value == 'home') {
                  Navigator.popUntil(context, (route) => route.isFirst);
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'home',
                  child: Text('Kembali ke Halaman Utama'),
                ),
              ],
            ),
          )
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImageGallery(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _product!['name']?.toString() ?? 'No Name',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_product!['price_ori'] != null && (_product!['price_ori'] as num) > (_product!['price_display'] as num))
                        Text(
                          'Rp ${_formatPrice(_product!['price_ori'])}',
                          style: const TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey,
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Rp ${_formatPrice(_product!['price_display'])}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF273F0),
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: Text(
                                  '${_formatSoldCount(_product!['sold'] ?? 0)} terjual',
                                  style: const TextStyle(color: Colors.black),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _isCheckingFavorite
                                  ? const CircularProgressIndicator(color: Color(0xFFF273F0))
                                  : Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      child: IconButton(
                                        icon: Icon(
                                          _isFavorite ? Icons.favorite : Icons.favorite_border,
                                          color: _isFavorite ? Colors.red : Colors.black,
                                          size: 20,
                                        ),
                                        padding: EdgeInsets.zero,
                                        onPressed: _toggleFavorite,
                                      ),
                                    ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Stok: $_availableStock',
                        style: TextStyle(
                          fontSize: 14,
                          color: _availableStock > 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(height: 32, thickness: 1),
                      const Text(
                        'Deskripsi Produk',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                          Text(
                            'Berat : ${_product!['weight']?.toString() ?? '0'} gram',
                            style: const TextStyle(fontSize: 14),
                          ),

                      const SizedBox(height: 8),
                      Text(
                        _product!['desc']?.toString() ?? 'Tidak ada deskripsi',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_showFullImage) _buildFullImagePreview(),
        ],
      ),
      bottomNavigationBar: Container(
        height: 90,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(50),
              ),
              child: IconButton(
                icon: const Icon(Icons.chat, color: Colors.black, size: 28),
                padding: EdgeInsets.zero,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ChatPage()),
                  );
                },
              ),
            ),
            const SizedBox(width: 30),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(50),
              ),
              child: IconButton(
                icon: const Icon(Icons.shopping_cart, color: Colors.black, size: 28),
                padding: EdgeInsets.zero,
                onPressed: _availableStock > 0 ? _addToCart : null,
              ),
            ),
            const SizedBox(width: 30),
            Expanded(
              child: SizedBox(
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _availableStock > 0 ? const Color(0xFFFF1E00) : Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _availableStock > 0 ? _buyNow : null,
                  child: Text(
                    _availableStock > 0 ? 'Beli Sekarang' : 'Stok Habis',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}