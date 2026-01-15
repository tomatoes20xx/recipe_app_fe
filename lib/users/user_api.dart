import "../api/api_client.dart";
import "user_models.dart";

class UserApi {
  UserApi(this.api);
  final ApiClient api;

  /// Search for users by username
  Future<UserSearchResponse> searchUsers({
    required String query,
    int limit = 20,
    String? cursor,
  }) async {
    final queryParams = <String, String>{
      "q": query,
      "limit": limit.toString(),
      if (cursor != null) "cursor": cursor,
    };

    final data = await api.get("/search/users", query: queryParams, auth: true);
    return UserSearchResponse.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Get user profile by username
  Future<UserProfile> getUserProfile(String username) async {
    final data = await api.get("/users/$username", auth: true);
    return UserProfile.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Follow a user
  Future<void> followUser(String username) async {
    await api.put("/users/$username/follow", auth: true);
  }

  /// Unfollow a user
  Future<void> unfollowUser(String username) async {
    await api.delete("/users/$username/follow", auth: true);
  }
}
