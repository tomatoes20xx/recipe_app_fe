import "package:flutter/foundation.dart";

import "auth_api.dart";
import "token_storage.dart";

class AuthController extends ChangeNotifier {
  AuthController({
    required this.authApi,
    required this.tokenStorage,
  });

  final AuthApi authApi;
  final TokenStorage tokenStorage;

  bool isLoading = false;
  String? token;
  Map<String, dynamic>? me;

  bool get isLoggedIn => token != null && token!.isNotEmpty;

  Future<void> bootstrap() async {
    try {
      token = await tokenStorage.readToken();
      if (token == null || token!.isEmpty) {
        me = null;
        notifyListeners();
        return;
      }

      // Add timeout to prevent hanging if server is unreachable
      try {
        me = await authApi.me().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            // Server unreachable - treat as logged out
            return null;
          },
        );
        if (me == null) {
          await logout();
          return;
        }
      } catch (e) {
        // token invalid / server unreachable -> treat as logged out
        await logout();
        return;
      }

      notifyListeners();
    } catch (e) {
      // Any error during bootstrap - just treat as logged out
      token = null;
      me = null;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    isLoading = true;
    notifyListeners();

    try {
      final t = await authApi.login(email: email, password: password);
      token = t;
      await tokenStorage.saveToken(t);
      me = await authApi.me();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signup({
    required String email,
    required String password,
    required String username,
    String? displayName,
  }) async {
    isLoading = true;
    notifyListeners();

    try {
      final t = await authApi.signup(
        email: email,
        password: password,
        username: username,
        displayName: displayName,
      );
      token = t;
      await tokenStorage.saveToken(t);
      me = await authApi.me();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    token = null;
    me = null;
    await tokenStorage.deleteToken();
    notifyListeners();
  }
}
