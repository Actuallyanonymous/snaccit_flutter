import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';

import 'firebase_options.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/restaurant_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/order_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/payment_status_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  
  runApp(const SnaccitApp());
}

class SnaccitApp extends StatefulWidget {
  const SnaccitApp({super.key});

  @override
  State<SnaccitApp> createState() => _SnaccitAppState();
}

class _SnaccitAppState extends State<SnaccitApp> {
  late final AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    // Listen for incoming deep links while the app is running
    _appLinks.uriLinkStream.listen((Uri uri) {
      debugPrint('🔗 Deep link received: $uri');
      _handleDeepLink(uri);
    });

    // Check if the app was launched via a deep link
    _appLinks.getInitialLink().then((Uri? uri) {
      if (uri != null) {
        debugPrint('🔗 Initial deep link: $uri');
        _handleDeepLink(uri);
      }
    });
  }

  void _handleDeepLink(Uri uri) {
    // Handle snaccit://payment-status?orderId=...
    if (uri.scheme == 'snaccit' && uri.host == 'payment-status') {
      final orderId = uri.queryParameters['orderId'] ?? '';
      if (orderId.isNotEmpty) {
        debugPrint('🔗 Navigating to PaymentStatusScreen for order: $orderId');
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => PaymentStatusScreen(orderId: orderId),
          ),
          (route) => route.isFirst,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RestaurantProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Snaccit',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
