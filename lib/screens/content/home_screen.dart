import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/screens/widget/appbar_a.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/register.dart';
import 'package:citraapp/screens/content/product_detail_page.dart';

class HomeContent extends StatefulWidget {
  @override
  _HomeContentState createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  bool _showPopup = false;
  bool _isCheckingSession = true;
  bool _temporarilyHidden = false;
  bool _popupShown = false;
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _products = [];
  bool _isLoadingProducts = true;
  final String _bucketName = 'picture-products';

  @override
  void initState() {
    super.initState();
    _checkUserSession();
    supabase.auth.onAuthStateChange.listen((AuthState data) {
      _handleAuthChange(data.session);
    });
    _fetchProducts();
  }

  Future<void> _refreshProducts() async {
    setState(() {
      _isLoadingProducts = true;
    });
    await _fetchProducts();
  }

  void _navigateToProductDetail(BuildContext context, String productId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailPage(
          productId: productId,
        ),
      ),
    );
    
    if (result == true) {
      await _refreshProducts();
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

  Future<void> _fetchProducts() async {
    try {
      // Pertama ambil produk tanpa foto
      final productsResponse = await supabase
          .from('products')
          .select('id, name, price_display, sold')
          .order('created_at', ascending: false);

      // Kemudian ambil foto pertama untuk setiap produk
      final productsWithPhotos = await Future.wait(
        (productsResponse as List<dynamic>).map<Future<Map<String, dynamic>>>((product) async {
          try {
            final photoResponse = await supabase
                .from('photo_items')
                .select('name')
                .eq('product_id', product['id'])
                .order('created_at', ascending: true)
                .limit(1);

            return {
              ...product,
              'photo': photoResponse.isNotEmpty ? photoResponse[0]['name'] : null,
            };
          } catch (e) {
            // Jika error saat mengambil foto, tetap return produk dengan photo null
            return {
              ...product,
              'photo': null,
            };
          }
        }).toList(),
      );

      if (mounted) {
        setState(() {
          _products = productsWithPhotos;
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
        });
      }
      print('Error fetching products: $e');
    }
  }

  String _getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';
    
    if (imagePath.startsWith('http')) {
      return imagePath;
    }
    
    return supabase.storage.from(_bucketName).getPublicUrl(imagePath);
  }

  void _handleAuthChange(Session? session) async {
    if (mounted && !_popupShown) {
      final prefs = await SharedPreferences.getInstance();
      final hasUserId = prefs.getString('user_id') != null;
      
      setState(() {
        _showPopup = (session == null && !hasUserId) && !_temporarilyHidden;
        _isCheckingSession = false;
      });
      
      if (_showPopup) {
        _showRegisterDialog();
      }
    }
  }
   
  Future<void> _checkUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasUserId = prefs.getString('user_id') != null;
      final session = supabase.auth.currentSession;
      
      if (mounted && !_popupShown) {
        setState(() {
          _showPopup = (session == null && !hasUserId) && !_temporarilyHidden;
          _isCheckingSession = false;
        });
        
        if (_showPopup) {
          _showRegisterDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingSession = false;
          _showPopup = !_temporarilyHidden && !_popupShown;
        });
        
        if (_showPopup) {
          _showRegisterDialog();
        }
      }
    }
  }

  void _navigateToRegister(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RegisterPage()),
    );
  }

  Future<void> _showRegisterDialog() async {
    if (_popupShown) return;
    
    setState(() {
      _popupShown = true;
    });
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(24),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 350),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Untuk bisa menikmati fitur aplikasi ini silahkan daftar terlebih dahulu',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 10),
                Text(
                  'Tanpa daftar terlebih dahulu, anda tidak bisa mengakses aplikasi ini. Apakah anda ingin mendaftar?',
                  style: TextStyle(color: Colors.grey[700], fontSize: 16),
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 21),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _temporarilyHidden = true;
                        });
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Sudah Daftar',
                        style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 21),
                    TextButton(
                      onPressed: () => _navigateToRegister(context),
                      child: const Text(
                        'Daftar',
                        style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSession) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBarA(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 4),
            // Banner
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/banner.png',
                  width: double.infinity,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // Products
            Padding(
              padding: EdgeInsets.all(16),
              child: _isLoadingProducts
                  ? Center(child: CircularProgressIndicator())
                  : _buildProductGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive grid based on screen width
        final crossAxisCount = constraints.maxWidth > 600 
            ? 4 
            : constraints.maxWidth > 400 
                ? 3 
                : 2;
        
        return GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.7, // Adjusted aspect ratio
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
          ),
          itemCount: _products.length,
          itemBuilder: (context, index) {
            final product = _products[index];
            final imageUrl = _getImageUrl(product['photo'] ?? '');
            final soldCount = product['sold'] ?? 0;
            final formattedSold = _formatSoldCount(soldCount is int ? soldCount : int.tryParse(soldCount.toString()) ?? 0);
            
            return ProductCard(
              imageUrl: imageUrl,
              title: product['name'] ?? 'No Name',
              price: 'Rp ${(product['price_display']?.toStringAsFixed(0)?.replaceAllMapped(
                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                (Match m) => '${m[1]}.',
              ) ?? '0')}',
              sold: '$formattedSold terjual',
              onTap: () => _navigateToProductDetail(context, product['id'].toString()),
            );
          },
        );
      }
    );
  }
}

class ProductCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String price;
  final String sold;
  final VoidCallback onTap;

  const ProductCard({
    required this.imageUrl,
    required this.title,
    required this.price,
    required this.sold,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate font sizes based on card width
        final titleFontSize = constraints.maxWidth * 0.045;
        final priceFontSize = constraints.maxWidth * 0.05;
        final soldFontSize = constraints.maxWidth * 0.035;

        return GestureDetector(
          onTap: onTap,
          child: Card(
            elevation: 4,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              constraints: BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Image container with fixed aspect ratio
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        color: Colors.grey[200],
                      ),
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
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
                  
                  // Content container with flexible padding
                  Padding(
                    padding: EdgeInsets.all(constraints.maxWidth * 0.04), // Responsive padding
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title with max lines and overflow
                        SizedBox(
                          height: constraints.maxWidth * 0.12, // Fixed height for title
                          child: Text(
                            title,
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: titleFontSize,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        
                        SizedBox(height: constraints.maxWidth * 0.02),
                        
                        // Price
                        Text(
                          price,
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: priceFontSize,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        SizedBox(height: constraints.maxWidth * 0.02),
                        
                        // Bottom row with icons and sold count
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.local_shipping,
                                  color: Colors.grey,
                                  size: constraints.maxWidth * 0.05,
                                ),
                                SizedBox(width: constraints.maxWidth * 0.02),
                                Icon(
                                  Icons.credit_card, 
                                  color: Colors.grey, 
                                  size: constraints.maxWidth * 0.05,
                                ),
                              ],
                            ),
                            // Sold count with limited width
                            Container(
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth * 0.35,
                              ),
                              child: Text(
                                sold,
                                style: TextStyle(
                                  color: Colors.grey, 
                                  fontSize: soldFontSize,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
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
        );
      },
    );
  }
}