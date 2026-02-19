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

  /// Whether the account is permanently banned (is_active = false)
  bool get isPermanentlyBanned => me?["is_active"] == false;

  /// When the soft ban expires, or null if not soft-banned
  DateTime? get softBannedUntil {
    final raw = me?["soft_banned_until"];
    if (raw == null) return null;
    try {
      final dt = DateTime.parse(raw.toString());
      return dt.isAfter(DateTime.now()) ? dt : null;
    } catch (_) {
      return null;
    }
  }

  /// Whether the account is currently soft-banned (can't post or comment)
  bool get isSoftBanned => softBannedUntil != null;

  /// Whether the account can post recipes and comments
  bool get canPost => isLoggedIn && !isSoftBanned && !isPermanentlyBanned;

  /// Number of violations (0–5)
  int get violationCount {
    final raw = me?["violation_count"];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 0;
  }

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

  /// Login with Google OAuth (Step 1)
  /// Takes an ID token from Google Sign-In
  /// Returns GoogleAuthResponse - check needsUsername to see if username selection is required
  Future<GoogleAuthResponse> loginWithGoogle(String idToken) async {
    isLoading = true;
    notifyListeners();

    try {
      final response = await authApi.googleLogin(idToken: idToken);

      // If existing user (no username needed), complete login immediately
      if (!response.needsUsername && response.token != null) {
        token = response.token;
        await tokenStorage.saveToken(response.token!);
        me = await authApi.me();
      }

      return response;
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

  Future<void> verifyEmail(String token) async {
    isLoading = true;
    notifyListeners();

    try {
      await authApi.verifyEmail(token);
      // Refresh user data to get updated emailVerified status
      me = await authApi.me();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resendVerificationEmail() async {
    isLoading = true;
    notifyListeners();

    try {
      await authApi.resendVerificationEmail();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> requestPasswordReset(String email) async {
    isLoading = true;
    notifyListeners();

    try {
      await authApi.requestPasswordReset(email);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    isLoading = true;
    notifyListeners();

    try {
      await authApi.resetPassword(
        email: email,
        code: code,
        newPassword: newPassword,
      );
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
