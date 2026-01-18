import "dart:io" show Platform;
import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/material.dart";
import "package:sqflite_common_ffi/sqflite_ffi.dart";

import "api/api_client.dart";
import "auth/auth_api.dart";
import "auth/auth_controller.dart";
import "auth/token_storage.dart";
import "screens/auth_gate.dart";
import "theme/theme_controller.dart";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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

  runApp(MyApp(
    authController: authController,
    apiClient: apiClient,
    themeController: themeController,
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.authController,
    required this.apiClient,
    required this.themeController,
  });
  final AuthController authController;
  final ApiClient apiClient;
  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return MaterialApp(
          title: "Recipe App",
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD93900), brightness: Brightness.light)
                .copyWith(primary: const Color(0xFFD93900), onPrimary: Colors.white),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD93900), brightness: Brightness.dark)
                .copyWith(primary: const Color(0xFFD93900), onPrimary: Colors.white, surface: Colors.grey[900]!, onSurface: Colors.white),
          ),
          themeMode: themeController.themeMode,
          home: AuthGate(
            auth: authController,
            apiClient: apiClient,
            themeController: themeController,
          ),
        );
      },
    );
  }
}
