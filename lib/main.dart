import 'dart:async';
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

    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacementNamed(context, '/home');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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