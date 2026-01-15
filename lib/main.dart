import "package:flutter/material.dart";

import "api/api_client.dart";
import "auth/auth_api.dart";
import "auth/auth_controller.dart";
import "auth/token_storage.dart";
import "screens/auth_gate.dart";
import "theme/theme_controller.dart";

void main() {
  WidgetsFlutterBinding.ensureInitialized();

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
          theme: ThemeData(useMaterial3: true),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.dark(
              primary: Colors.blue,
              secondary: Colors.blueAccent,
              surface: Colors.grey[900]!,
              onSurface: Colors.white,
              background: Colors.black,
            ),
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
