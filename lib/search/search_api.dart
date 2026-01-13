import "../api/api_client.dart";
import "search_models.dart";

class SearchApi {
  SearchApi(this.api);
  final ApiClient api;

  Future<SearchResponse> searchRecipes({
    required String query,
    int limit = 20,
    String? cursor,
  }) async {
    final queryParams = <String, String>{
      "q": query,
      "limit": limit.toString(),
      if (cursor != null) "cursor": cursor,
    };

    final data = await api.get("/search/recipes", query: queryParams, auth: true);
    return SearchResponse.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
