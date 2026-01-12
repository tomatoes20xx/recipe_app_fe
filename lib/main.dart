import "package:flutter/material.dart";

import "api/api_client.dart";
import "auth/auth_api.dart";
import "auth/auth_controller.dart";
import "auth/token_storage.dart";
import "screens/auth_gate.dart";

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final tokenStorage = TokenStorage();
  final apiClient = ApiClient(tokenStorage: tokenStorage);
  final authApi = AuthApi(apiClient);
  final authController = AuthController(authApi: authApi, tokenStorage: tokenStorage);

  runApp(MyApp(authController: authController, apiClient: apiClient));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.authController, required this.apiClient});
  final AuthController authController;
  final ApiClient apiClient;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Recipe App",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: AuthGate(auth: authController, apiClient: apiClient),
    );
  }
}
