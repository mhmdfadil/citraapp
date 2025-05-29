import 'dart:async';
import 'dart:math';
import 'package:citraapp/screens/content/promo_page.dart';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/user_screen.dart';
import 'package:citraapp/screens/content/product_detail_page.dart';
import '/utils/supabase_init.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseInit.initialize();
  await Permission.storage.request();
  String initialRoute = await _getInitialRoute() ?? '/';
  
  runApp(MyApp(initialRoute: initialRoute));
}

class MyApp extends StatefulWidget {
  final String initialRoute;

  const MyApp({super.key, required this.initialRoute});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> initDeepLinks() async {
    _appLinks = AppLinks();

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme == 'citraapp' && uri.host == 'product') {
      final productId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      _navigateToProduct(productId);
    } else if (uri.host == 'citra-cosmetic.github.io' && 
               uri.path == '/app_flutter/deeplink.html' &&
               uri.queryParameters.containsKey('product')) {
      final productPath = uri.queryParameters['product'] ?? '';
      final productId = productPath.split('/').last;
      _navigateToProduct(productId);
    }
  }

  void _navigateToProduct(String productId) {
    if (productId.isNotEmpty) {
      Navigator.of(context).pushNamed(
        '/product/$productId',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Citra Cosmetic',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: widget.initialRoute,
      routes: {
        '/': (context) => const SplashScreen(),
        '/home': (context) => UserScreen(),
        '/promo': (context) => PromoPage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name?.startsWith('/product/') ?? false) {
          final productId = settings.name?.split('/product/')[1] ?? '';
          return MaterialPageRoute(
            builder: (context) => ProductDetailPage(productId: productId),
            settings: settings,
          );
        }
        return null;
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _textSlideAnimation;
  late Animation<Color?> _colorAnimation;
  bool _showSecondSplash = false;
  Map<String, dynamic>? _promoData;
  String? _imageUrl;
  bool _hasActivePromo = false;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // Initialize animations
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.5, end: 1.2), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.2, end: 1.0), weight: 50),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );

    _textSlideAnimation = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _colorAnimation = ColorTween(
      begin: Colors.white.withOpacity(0.8),
      end: Colors.red[800]?.withOpacity(0.9),
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeInOut),
      ),
    );

    _controller.forward();

    // Load promo data
    _loadPromoData().then((hasPromo) {
      if (hasPromo) {
        setState(() {
          _showSecondSplash = true;
          _hasActivePromo = true;
        });
        
        Timer(const Duration(seconds: 8), () {
          Navigator.pushReplacementNamed(context, '/home');
        });
      } else {
        // No active promo, skip second splash
        Timer(const Duration(seconds: 3), () {
          Navigator.pushReplacementNamed(context, '/home');
        });
      }
    });
  }

 Future<bool> _loadPromoData() async {
  try {
    final now = DateTime.now();
    
    // Fetch all active promotions that match current date/time
    final response = await Supabase.instance.client
        .from('promos')
        .select('''
          *, 
          products:product_id(name, price_ori, diskon)
        ''')
        .lte('start_date', now.toIso8601String())
        .gte('end_date', now.toIso8601String());

    if (response != null && response.isNotEmpty) {
      // Randomly select one promo from the list
      final random = Random();
      final randomIndex = random.nextInt(response.length);
      
      setState(() {
        _promoData = response[randomIndex] as Map<String, dynamic>;
      });

      // Get the product ID from promo
      final productId = _promoData?['product_id'];
      
      if (productId != null) {
        // Fetch the first image for this product from photo_items
        final photoResponse = await Supabase.instance.client
            .from('photo_items')
            .select('name')
            .eq('product_id', productId)
            .order('created_at', ascending: true)
            .limit(1)
            .single();

        if (photoResponse != null && photoResponse['name'] != null) {
          final imagePath = photoResponse['name'];
          
          final url = Supabase.instance.client
              .storage
              .from('picture-products')
              .getPublicUrl(imagePath);
              
          setState(() {
            _imageUrl = url;
          });
        }
      }
      return true;
    }
    return false;
  } catch (e) {
    debugPrint('Error loading promo data: $e');
    return false;
  }
}

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showSecondSplash && _hasActivePromo) {
      return _buildSecondSplashScreen();
    }
    
    return _buildFirstSplashScreen();
  }

  Widget _buildFirstSplashScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _colorAnimation.value ?? Colors.white,
                  Colors.white,
                ],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: Image.asset(
                        'assets/images/logos.png',
                        width: 200,
                        height: 200,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Transform.translate(
                      offset: Offset(0, _textSlideAnimation.value),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            'Citra',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Colors.red[800],
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Cosmetic',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w500,
                              color: Colors.red[800],
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSecondSplashScreen() {
    if (_promoData == null) {
      return _buildFirstSplashScreen();
    }

    final productName = _promoData?['products']?['name'] ?? 'Premium Product';
    final originalPrice = _promoData?['products']?['price_ori']?.toDouble() ?? 0.0;
    final discountPrice = _promoData?['price_display']?.toDouble() ?? 
                         (originalPrice * (1 - (_promoData?['diskon'] ?? 0) / 100));
    final discountPercentage = _promoData?['diskon']?.toInt() ?? 0;
    
    // Format dates
    final startDate = _promoData?['start_date'] != null 
        ? DateTime.parse(_promoData!['start_date']).toLocal()
        : DateTime.now();
    final endDate = _promoData?['end_date'] != null 
        ? DateTime.parse(_promoData!['end_date']).toLocal()
        : DateTime.now().add(const Duration(days: 7));
    
    final dateRange = '${_formatDate(startDate)} - ${_formatDate(endDate)}';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.5,
            colors: [
              Color(0xFF2A0A3D), // Deep purple
              Color(0xFF4A148C), // Rich purple
              Color(0xFF7B1FA2), // Vibrant purple
              Color(0xFF9C27B0), // Purple
              Color(0xFFBA68C8), // Light purple
              Color(0xFFE1BEE7), // Very light purple
            ],
            stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Floating stars decoration
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  child: CustomPaint(
                    painter: StarFieldPainter(),
                  ),
                ),
              ),
            ),
            
            // Floating shopping bags decoration
            Positioned(
              top: 20,
              right: 30,
              child: Opacity(
                opacity: 0.6,
                child: Icon(
                  Icons.shopping_bag,
                  size: 60,
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
            ),
            
            Positioned(
              bottom: 80,
              left: 40,
              child: Opacity(
                opacity: 0.4,
                child: Icon(
                  Icons.shopping_cart,
                  size: 50,
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
            ),
            
            // Main content
            Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Premium badge with stars
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.amber[700]?.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'SPECIAL PROMOTION',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: 16),
                      
                      // Promo period with countdown
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Promo Period',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              dateRange,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: 16),
                      
                      // Product Image with luxurious frame
                      Hero(
                        tag: 'promo-hero',
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.amber.withOpacity(0.5),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 30,
                                spreadRadius: 5,
                                offset: Offset(0, 15),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      Colors.purple.withOpacity(0.8),
                                      Colors.transparent,
                                    ],
                                    stops: [0.1, 0.9],
                                  ),
                                ),
                              ),
                              Container(
                                width: 180,
                                height: 180,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: _imageUrl != null
                                      ? Image.network(
                                          _imageUrl!,
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
                                          errorBuilder: (context, error, stackTrace) {
                                            return Icon(Icons.image_not_supported, 
                                              color: Colors.white, size: 50);
                                          },
                                        )
                                      : Icon(Icons.image_not_supported, 
                                          color: Colors.white, size: 50),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 28),
                      
                      // Product name
                      Text(
                        productName.toUpperCase(),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      SizedBox(height: 8),
                      
                      // Price information
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (discountPercentage > 0)
                            Text(
                              'Rp${originalPrice.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.7),
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          if (discountPercentage > 0) SizedBox(width: 10),
                          Text(
                            'Rp${discountPrice.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[300],
                            ),
                          ),
                          if (discountPercentage > 0) SizedBox(width: 10),
                          if (discountPercentage > 0)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red[800],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$discountPercentage% OFF',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      
                      SizedBox(height: 25),
                      
                      // SPECIAL OFFER section
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Background glow
                          Container(
                            width: 320,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withOpacity(0.4),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          
                          // Main offer container
                          Container(
                            width: 260,
                            padding: EdgeInsets.symmetric(vertical: 15),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFFFD700),
                                  Color(0xFFFFC400),
                                  Color(0xFFFFAB00),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'LIMITED TIME OFFER',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                
                                SizedBox(height: 5),
                                
                                Text(
                                  'Hurry! Offer ends soon',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red[900],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 30),
                      
                      // Shop Now Button
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withOpacity(0.6),
                              blurRadius: 20,
                              spreadRadius: 2,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushReplacementNamed(context, '/promo');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.purple[900],
                            padding: EdgeInsets.symmetric(horizontal: 50, vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 15,
                            shadowColor: Colors.black.withOpacity(0.4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.shopping_cart,
                                size: 24,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'SHOP NOW',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// Custom painter for star field background
class StarFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    
    final random = Random(42); // Fixed seed for consistent stars
    
    // Draw many small stars
    for (int i = 0; i < 150; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 1.5;
      
      if (random.nextDouble() > 0.9) {
        // Draw some twinkling stars
        paint.color = Colors.amber.withOpacity(random.nextDouble() * 0.4 + 0.1);
        canvas.drawCircle(Offset(x, y), radius * 2, paint);
      } else {
        paint.color = Colors.white.withOpacity(random.nextDouble() * 0.2 + 0.05);
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
    
    // Draw some larger stars
    for (int i = 0; i < 20; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 3 + 2;
      
      paint.color = Colors.amber.withOpacity(random.nextDouble() * 0.3 + 0.2);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Future<String?> _getInitialRoute() async {
  try {
    final appLinks = AppLinks();
    final initialUri = await appLinks.getInitialAppLink();
    
    if (initialUri != null) {
      if (initialUri.scheme == 'citraapp' && initialUri.host == 'product') {
        final productId = initialUri.pathSegments.isNotEmpty 
            ? initialUri.pathSegments.first 
            : '';
        return '/product/$productId';
      }
      else if (initialUri.host == 'citra-cosmetic.github.io' && 
               initialUri.path == '/app_flutter/deeplink.html' &&
               initialUri.queryParameters.containsKey('product')) {
        final productPath = initialUri.queryParameters['product'] ?? '';
        final productId = productPath.split('/').last;
        return '/product/$productId';
      }
    }
    
    return null;
  } catch (e) {
    debugPrint('Error getting initial route: $e');
    return null;
  }
}

extension on AppLinks {
  getInitialAppLink() {}
}