import "dart:io";

import "package:http/http.dart" as http;

import "../api/api_client.dart";

class AuthApi {
  AuthApi(this.api);
  final ApiClient api;

  Future<String> signup({
    required String email,
    required String password,
    required String username,
    String? displayName,
  }) async {
    final data = await api.post("/auth/signup", body: {
      "email": email,
      "password": password,
      "username": username,
      "displayName": displayName,
    });

    final token = (data["token"] ?? "").toString();
    if (token.isEmpty) throw ApiException(500, "No token returned from signup");

    await api.tokenStorage.saveToken(token); // ✅ store
    return token;
  }

  /// Verify email with verification token
  Future<void> verifyEmail(String token) async {
    await api.post("/auth/verify-email", body: {
      "code": token,  // Backend expects "code", not "token"
    }, auth: true);
  }

  /// Resend verification email
  Future<void> resendVerificationEmail() async {
    await api.post("/auth/resend-verification", auth: true);
  }

  /// Check if current user's email is verified
  Future<bool> isEmailVerified() async {
    try {
      final data = await api.get("/me", auth: true);
      if (data == null) return false;
      final user = Map<String, dynamic>.from(data as Map);
      return user["emailVerified"] == true;
    } catch (_) {
      return false;
    }
  }

  /// Request password reset - sends reset code to email
  Future<void> requestPasswordReset(String email) async {
    await api.post("/auth/forgot-password", body: {
      "email": email,
    });
  }

  /// Reset password with code
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await api.post("/auth/reset-password", body: {
      "email": email,
      "code": code,
      "newPassword": newPassword,
    });
  }

  Future<String> login({
    required String email,
    required String password,
  }) async {
    final data = await api.post("/auth/login", body: {
      "email": email,
      "password": password,
    });

    final token = (data["token"] ?? "").toString();
    if (token.isEmpty) throw ApiException(500, "No token returned from login");

    await api.tokenStorage.saveToken(token); // ✅ store
    return token;
  }

  /// Login with Google OAuth
  /// Takes an ID token from Google Sign-In and exchanges it for a JWT
  Future<String> googleLogin({required String idToken}) async {
    final data = await api.post("/auth/google", body: {
      "idToken": idToken,
    });

    final token = (data["token"] ?? "").toString();
    if (token.isEmpty) throw ApiException(500, "No token returned from Google login");

    await api.tokenStorage.saveToken(token); // ✅ store
    return token;
  }

  Future<void> logout() async {
    await api.tokenStorage.deleteToken(); // ✅ clear
  }

  Future<Map<String, dynamic>?> me() async {
    final data = await api.get("/me", auth: true);
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> uploadAvatar(File imageFile) async {
    final length = await imageFile.length();
    final filename = imageFile.path.split('/').last;
    final extension = filename.split('.').last.toLowerCase();
    
    // Determine content type
    String contentType;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        contentType = 'image/jpeg';
        break;
      case 'png':
        contentType = 'image/png';
        break;
      case 'webp':
        contentType = 'image/webp';
        break;
      default:
        contentType = 'image/jpeg';
    }
    
    final multipartFile = http.MultipartFile(
      'file',
      imageFile.openRead(),
      length,
      filename: filename,
      contentType: http.MediaType.parse(contentType),
    );
    
    final data = await api.postMultipart(
      "/users/me/avatar",
      fields: {},
      files: [multipartFile],
      auth: true,
    );
    
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> deleteAvatar() async {
    await api.delete("/users/me/avatar", auth: true);
  }
}
