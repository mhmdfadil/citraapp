import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/screens/widget/appbar_a.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/register.dart';
import 'package:citraapp/screens/content/product_detail_page.dart'; // Import the product detail page

class HomeContent extends StatefulWidget {
  @override
  _HomeContentState createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  bool _showPopup = false;
  bool _isCheckingSession = true;
  bool _temporarilyHidden = false;
  bool _popupShown = false; // Track if popup has been shown
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _products = [];
  bool _isLoadingProducts = true;
  final String _bucketName = 'picture-products'; // Supabase bucket name

  @override
  void initState() {
    super.initState();
    _checkUserSession();
    supabase.auth.onAuthStateChange.listen((AuthState data) {
      _handleAuthChange(data.session);
    });
    _fetchProducts();
  }

  // Function to format sold count with detailed ranges
  String _formatSoldCount(int sold) {
    if (sold < 10) {
      return sold.toString();
    } else if (sold < 100) {
      return '10+';
    } else if (sold < 1000) {
      return '100+';
    } else if (sold < 10000) {
      return '1RB+';
    } else if (sold < 100000) {
      return '10RB+';
    } else if (sold < 1000000) {
      return '100RB+';
    } else {
      return '1JT+';
    }
  }

  Future<void> _fetchProducts() async {
    try {
      final response = await supabase
          .from('products')
          .select('id, name, price_display, photos, sold')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _products = List<Map<String, dynamic>>.from(response);
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

  String _getImageUrl(String imagePath) {
    if (imagePath.isEmpty) return '';
    
    // If it's already a full URL, return as is
    if (imagePath.startsWith('http')) {
      return imagePath;
    }
    
    // Get the public URL from Supabase Storage
    final String publicUrl = supabase
        .storage
        .from(_bucketName)
        .getPublicUrl(imagePath);
    
    return publicUrl;
  }

  void _handleAuthChange(Session? session) async {
    if (mounted && !_popupShown) { // Only handle if popup hasn't been shown
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
      
      if (mounted && !_popupShown) { // Only check if popup hasn't been shown
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
    Navigator.pop(context); // Close the dialog first
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RegisterPage()),
    );
  }

  Future<void> _showRegisterDialog() async {
    if (_popupShown) return; // Prevent showing popup multiple times
    
    setState(() {
      _popupShown = true;
    });
    
    await showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing by tapping outside
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
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
        
        return GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.68,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
          ),
          itemCount: _products.length,
          itemBuilder: (context, index) {
            final product = _products[index];
            final imageUrl = _getImageUrl(product['photos'] ?? '');
            final soldCount = product['sold'] ?? 0;
            final formattedSold = _formatSoldCount(soldCount is int ? soldCount : int.tryParse(soldCount.toString()) ?? 0);
            
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductDetailPage(
                      productId: product['id'].toString(),
                    ),
                  ),
                );
              },
              child: ProductCard(
                imageUrl: imageUrl,
                title: product['name'] ?? 'No Name',
                price: 'Rp ${(product['price_display']?.toStringAsFixed(0)?.replaceAllMapped(
                  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                  (Match m) => '${m[1]}.',
                ) ?? '0')}',
                sold: '$formattedSold terjual',
              ),
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

  const ProductCard({
    required this.imageUrl,
    required this.title,
    required this.price,
    required this.sold,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        constraints: BoxConstraints(
          minHeight: 0, // Remove minimum height constraints
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Important for proper sizing
          children: [
            // Square image container
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: double.infinity,
                        height: double.infinity,
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
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            ),
                      )
                    : Image.asset(
                        'assets/images/placeholder.png',
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            // Content with flexible space
            Flexible(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      price,
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.local_shipping,
                              color: Colors.grey,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.credit_card, color: Colors.grey, size: 16),
                          ],
                        ),
                        Container(
                          constraints: BoxConstraints(maxWidth: 70), // Limit width of sold text
                          child: Text(
                            sold,
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}