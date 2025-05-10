import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:citraapp/screens/content/cart_screen.dart';
import 'package:citraapp/screens/content/chat.dart';
import 'package:citraapp/screens/content/co_buy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:citraapp/login.dart';

class CardProduct {
  final int id;
  final int product_id;
  final String category;
  final String name;
  final String price;
  final String imageUrl;
  int quantity;
  bool isSelected;
  int stock;

  CardProduct({
    required this.id,
    required this.product_id,
    required this.category,
    required this.name,
    required this.price,
    required this.imageUrl,
    this.quantity = 1,
    this.isSelected = true,
    required this.stock,
  });
}

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
  String? _fullImageUrl;

  @override
  void initState() {
    super.initState();
    _fetchProduct();
    _fetchCartCount();
    _checkFavoriteStatus();
  }

  Future<void> _fetchProduct() async {
    try {
      final response = await _supabase
          .from('products')
          .select()
          .eq('id', widget.productId)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _product = response;
          _availableStock = response['stock'] ?? 0;
          if (response['photos'] != null && response['photos'].isNotEmpty) {
            _fullImageUrl = _supabase.storage.from('picture-products').getPublicUrl(response['photos']);
          }
        });
      } else {
        // Handle case where product is not found
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
    } finally {
      if (mounted) {
      }
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
    if (sold < 10) return sold.toString();
    if (sold < 100) return '10+';
    if (sold < 1000) return '100+';
    if (sold < 10000) return '1RB+';
    if (sold < 100000) return '10RB+';
    if (sold < 1000000) return '100RB+';
    return '1JT+';
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    final intPrice = price is int ? price : int.tryParse(price.toString()) ?? 0;
    return intPrice.toString().replaceAllMapped(
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

    final cardproduct = CardProduct(
      id: DateTime.now().millisecondsSinceEpoch,
      product_id: int.tryParse(widget.productId) ?? 0,
      category: _product!['category']?.toString() ?? '',
      name: _product!['name']?.toString() ?? 'No Name',
      price: _product!['price_display']?.toString() ?? '0',
      imageUrl: _product!['photos'] != null && _product!['photos'].isNotEmpty
          ? _supabase.storage.from('picture-products').getPublicUrl(_product!['photos'])
          : '',
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

  void _showImagePreview() {
    if (_fullImageUrl == null) return;
    
    setState(() {
      _showFullImage = true;
    });
  }

  void _hideImagePreview() {
    setState(() {
      _showFullImage = false;
    });
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
                GestureDetector(
                  onTap: _showImagePreview,
                  child: SizedBox(
                    height: 300,
                    width: double.infinity,
                    child: _product!['photos'] != null && _product!['photos'].isNotEmpty
                        ? Image.network(
                            _supabase.storage.from('picture-products').getPublicUrl(_product!['photos']),
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
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
                          )
                        : const Icon(Icons.image_not_supported),
                  ),
                ),
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
                        _product!['desc']?.toString() ?? 'Tidak ada deskripsi',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_showFullImage && _fullImageUrl != null)
            GestureDetector(
              onTap: _hideImagePreview,
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
                        child: Image.network(
                          _fullImageUrl!,
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
                  ],
                ),
              ),
            ),
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