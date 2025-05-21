import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
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

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    // Logo scale animation (grows then settles)
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.5, end: 1.2), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.2, end: 1.0), weight: 50),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // Fade animation for both logo and text
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );

    // Text slide-up animation
    _textSlideAnimation = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    // Background color animation
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

    Timer(const Duration(seconds: 4), () {
      setState(() {
        _showSecondSplash = true;
      });
      
      Timer(const Duration(seconds: 8), () {
        Navigator.pushReplacementNamed(context, '/home');
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showSecondSplash) {
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
                              'PREMIUM COSMETICS',
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
                      
                      // Cosmetic Image with luxurious frame
                      Hero(
                        tag: 'cosmetic-hero',
                        child: Container(
                          width: 180,
                          height: 180,
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
                                width: 150,
                                height: 150,
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
                                  child: Image.asset(
                                    'assets/images/logos.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 28),
                      
                      // Luxurious title with gradient
                      ShaderMask(
                        shaderCallback: (bounds) {
                          return LinearGradient(
                            colors: [
                              Colors.amber,
                              Colors.amberAccent,
                              Colors.white,
                            ],
                            stops: [0.0, 0.5, 1.0],
                          ).createShader(bounds);
                        },
                        child: Text(
                          'BEAUTY FOR EVERYONE',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 4,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 10,
                                offset: Offset(2, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 8),
                    
                      // Shopping text with icon
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_basket,
                            color: Colors.white,
                            size: 24,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'ONLINE SHOPPING',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 19),
                      
                      // Description Text with elegant border
                      Container(
                        padding: EdgeInsets.all(20),
                        margin: EdgeInsets.symmetric(horizontal: 30),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Experience the epitome of beauty with our exclusive collection. '
                          'Each product is crafted with premium ingredients to enhance your natural radiance.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                            height: 1.6,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 25),
                      
                      // SPECIAL OFFER section - The focal point
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
                                // Stars decoration
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(5, (index) => 
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 2),
                                      child: Icon(
                                        Icons.star,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                
                                SizedBox(height: 8),
                                
                                // Special offer text
                                Text(
                                  'SPECIAL OFFER',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                    letterSpacing: 2,
                                    shadows: [
                                      Shadow(
                                        color: Colors.white.withOpacity(0.5),
                                        blurRadius: 2,
                                        offset: Offset(1, 1),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                SizedBox(height: 5),
                                
                                // Discount text
                                Text(
                                  'UP TO 50% OFF',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red[900],
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 30),
                      
                      // Shop Now Button with luxury touch
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
                            Navigator.pushReplacementNamed(context, '/home');
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