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

  Future<void> logout() async {
    await api.tokenStorage.deleteToken(); // ✅ clear
  }

  Future<Map<String, dynamic>?> me() async {
    final data = await api.get("/me", auth: true);
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }
}
