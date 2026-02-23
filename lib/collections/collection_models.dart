class Collection {
  final String id;
  final String name;
  final int recipeCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Collection({
    required this.id,
    required this.name,
    required this.recipeCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Collection.fromJson(Map<String, dynamic> json) {
    return Collection(
      id: json["id"].toString(),
      name: json["name"].toString(),
      recipeCount: (json["recipe_count"] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json["created_at"].toString()),
      updatedAt: DateTime.parse(json["updated_at"].toString()),
    );
  }

  Collection copyWith({
    String? id,
    String? name,
    int? recipeCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Collection(
      id: id ?? this.id,
      name: name ?? this.name,
      recipeCount: recipeCount ?? this.recipeCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class CollectionsResponse {
  final List<Collection> items;
  final String? nextCursor;

  CollectionsResponse({
    required this.items,
    this.nextCursor,
  });

  factory CollectionsResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = (json["items"] as List?) ?? [];
    return CollectionsResponse(
      items: rawItems
          .map((e) => Collection.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      nextCursor: json["nextCursor"] as String?,
    );
  }
}

/// Represents which collection a recipe belongs to (can be null).
class RecipeCollectionInfo {
  final String collectionId;
  final String collectionName;

  RecipeCollectionInfo({
    required this.collectionId,
    required this.collectionName,
  });

  factory RecipeCollectionInfo.fromJson(Map<String, dynamic> json) {
    return RecipeCollectionInfo(
      collectionId: json["collection_id"].toString(),
      collectionName: json["collection_name"].toString(),
    );
  }
}
