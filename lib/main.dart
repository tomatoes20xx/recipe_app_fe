import "dart:io" show Platform;
import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/material.dart";
import "package:flutter_localizations/flutter_localizations.dart";
import "package:google_fonts/google_fonts.dart";
import "package:google_mobile_ads/google_mobile_ads.dart";
import "package:sqflite_common_ffi/sqflite_ffi.dart";

import "api/api_client.dart";
import "auth/auth_api.dart";
import "auth/auth_controller.dart";
import "auth/token_storage.dart";
import "localization/app_localizations.dart";
import "localization/language_controller.dart";
import "screens/auth_gate.dart";
import "theme/theme_controller.dart";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Google Mobile Ads SDK
  // App ID: ca-app-pub-5283215754482121~9547688424
  MobileAds.instance.initialize();
  
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

  runApp(MyApp(
    authController: authController,
    apiClient: apiClient,
    themeController: themeController,
    languageController: languageController,
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.authController,
    required this.apiClient,
    required this.themeController,
    required this.languageController,
  });
  final AuthController authController;
  final ApiClient apiClient;
  final ThemeController themeController;
  final LanguageController languageController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([themeController, languageController]),
      builder: (context, _) {
        return MaterialApp(
          title: "CookBook",
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
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF7622), brightness: Brightness.light)
                .copyWith(primary: const Color(0xFFFF7622), onPrimary: Colors.white),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            textTheme: GoogleFonts.nunitoTextTheme(ThemeData(brightness: Brightness.dark).textTheme),
            fontFamilyFallback: const ["Noto Sans Georgian", "Noto Sans"],
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF7622), brightness: Brightness.dark)
                .copyWith(primary: const Color(0xFFFF7622), onPrimary: Colors.white, surface: Colors.grey[900]!, onSurface: Colors.white),
          ),
          themeMode: themeController.themeMode,
          home: AuthGate(
            auth: authController,
            apiClient: apiClient,
            themeController: themeController,
            languageController: languageController,
          ),
        );
      },
    );
  }
}
