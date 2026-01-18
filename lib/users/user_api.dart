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

  /// Get recipes by a specific user
  Future<UserRecipesResponse> getUserRecipes({
    required String username,
    int limit = 20,
    String? cursor,
  }) async {
    final queryParams = <String, String>{
      "limit": limit.toString(),
      if (cursor != null) "cursor": cursor,
    };

    final data = await api.get("/users/$username/recipes", query: queryParams, auth: true);
    return UserRecipesResponse.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Get followers of a user
  Future<UserSearchResponse> getFollowers({
    required String username,
    int limit = 20,
    String? cursor,
  }) async {
    final queryParams = <String, String>{
      "limit": limit.toString(),
      if (cursor != null) "cursor": cursor,
    };

    final data = await api.get("/users/$username/followers", query: queryParams, auth: true);
    return UserSearchResponse.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Get users that a user is following
  Future<UserSearchResponse> getFollowing({
    required String username,
    int limit = 20,
    String? cursor,
  }) async {
    final queryParams = <String, String>{
      "limit": limit.toString(),
      if (cursor != null) "cursor": cursor,
    };

    final data = await api.get("/users/$username/following", query: queryParams, auth: true);
    return UserSearchResponse.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Update privacy settings
  Future<UserPrivacySettings> updatePrivacy({
    bool? followersPrivate,
    bool? followingPrivate,
  }) async {
    final body = <String, dynamic>{};
    if (followersPrivate != null) {
      body["followers_private"] = followersPrivate;
    }
    if (followingPrivate != null) {
      body["following_private"] = followingPrivate;
    }

    if (body.isEmpty) {
      throw Exception("At least one privacy field must be provided");
    }

    final data = await api.patch("/users/me/privacy", body: body, auth: true);
    return UserPrivacySettings.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Get user's bookmarked recipes
  Future<UserRecipesResponse> getBookmarkedRecipes({
    int limit = 20,
    String? cursor,
  }) async {
    final queryParams = <String, String>{
      "limit": limit.toString(),
      if (cursor != null) "cursor": cursor,
    };

    final data = await api.get("/users/me/bookmarks", query: queryParams, auth: true);
    return UserRecipesResponse.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
