import "dart:io" show Platform;
import "dart:ui";
import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/material.dart";
import "package:flutter_localizations/flutter_localizations.dart";
import "package:google_fonts/google_fonts.dart";
import "package:google_mobile_ads/google_mobile_ads.dart";
import "package:google_sign_in/google_sign_in.dart";
import "package:sqflite_common_ffi/sqflite_ffi.dart";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_crashlytics/firebase_crashlytics.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "firebase_options.dart";
import "services/notification_service.dart";

import "api/api_client.dart";
import "auth/auth_api.dart";
import "auth/auth_controller.dart";
import "auth/token_storage.dart";
import "localization/app_localizations.dart";
import "localization/language_controller.dart";
import "screens/auth_gate.dart";
import "shopping/shopping_list_api.dart";
import "shopping/shopping_list_controller.dart";
import "theme/theme_controller.dart";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (optional - will skip if not configured)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize Firebase Crashlytics
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };
    // Pass all uncaught asynchronous errors to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    // Initialize Firebase Messaging background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Initialize notification service
    await NotificationService().initialize();
  } catch (e) {
    // Firebase not configured - app will run without Firebase features
    // Run "flutterfire configure" to set up Firebase
  }

  // Initialize Google Mobile Ads SDK
  // App ID: ca-app-pub-3299728362959933~7231058371
  MobileAds.instance.initialize();

  // Initialize Google Sign-In with Web Client ID
  const String webClientId = '31640311657-vt82s1udbrrn2t36g3ivhh0jll148q4l.apps.googleusercontent.com';

  try {
    await GoogleSignIn.instance.initialize(
      serverClientId: webClientId,
    );
  } catch (e) {
    // Ignore initialization errors
  }
  
  // Initialize sqflite_common_ffi for Windows/Linux/macOS desktop support
  // This is required for cached_network_image to work on desktop platforms
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  // Clear image cache to ensure fresh images are loaded
  imageCache.clear();
  imageCache.clearLiveImages();

  final tokenStorage = TokenStorage();
  final apiClient = ApiClient(tokenStorage: tokenStorage);
  final authApi = AuthApi(apiClient);
  final authController = AuthController(authApi: authApi, tokenStorage: tokenStorage);
  final themeController = ThemeController();
  final languageController = LanguageController();
  final shoppingListApi = ShoppingListApi(apiClient);
  final shoppingListController = ShoppingListController(api: shoppingListApi);

  runApp(MyApp(
    authController: authController,
    apiClient: apiClient,
    themeController: themeController,
    languageController: languageController,
    shoppingListController: shoppingListController,
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.authController,
    required this.apiClient,
    required this.themeController,
    required this.languageController,
    required this.shoppingListController,
  });
  final AuthController authController;
  final ApiClient apiClient;
  final ThemeController themeController;
  final LanguageController languageController;
  final ShoppingListController shoppingListController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([themeController, languageController]),
      builder: (context, _) {
        return MaterialApp(
          title: "Yummy",
          debugShowCheckedModeBanner: false,
          locale: languageController.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            useMaterial3: true,
            textTheme: GoogleFonts.nunitoTextTheme(),
            fontFamilyFallback: const ["Noto Sans Georgian", "Noto Sans"],
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF53B175), brightness: Brightness.light)
                .copyWith(primary: const Color(0xFF53B175), onPrimary: Colors.white, secondary: Colors.white, onSecondary: Colors.black),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            textTheme: GoogleFonts.nunitoTextTheme(ThemeData(brightness: Brightness.dark).textTheme),
            fontFamilyFallback: const ["Noto Sans Georgian", "Noto Sans"],
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF53B175), brightness: Brightness.dark)
                .copyWith(primary: const Color(0xFF53B175), onPrimary: Colors.white, surface: Colors.grey[900]!, onSurface: Colors.white),
          ),
          themeMode: themeController.themeMode,
          home: AuthGate(
            auth: authController,
            apiClient: apiClient,
            themeController: themeController,
            languageController: languageController,
            shoppingListController: shoppingListController,
          ),
        );
      },
    );
  }
}
