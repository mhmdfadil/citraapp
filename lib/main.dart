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

    // Handle incoming links when app is running
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    // Handle both custom scheme and HTTPS links
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
        '/': (context) => UserScreen(),
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

Future<String?> _getInitialRoute() async {
  try {
    final appLinks = AppLinks();
    final initialUri = await appLinks.getInitialAppLink();
    
    if (initialUri != null) {
      // Handle custom scheme
      if (initialUri.scheme == 'citraapp' && initialUri.host == 'product') {
        final productId = initialUri.pathSegments.isNotEmpty 
            ? initialUri.pathSegments.first 
            : '';
        return '/product/$productId';
      }
      // Handle HTTPS links
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