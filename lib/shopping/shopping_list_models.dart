import "../sharing/sharing_models.dart";

class ShoppingListItem {
  ShoppingListItem({
    required this.id,
    required this.ingredientId,
    required this.name,
    this.quantity,
    this.unit,
    required this.recipeId,
    required this.recipeName,
    this.recipeImage,
    this.isChecked = false,
    required this.addedAt,
    this.sharedWith = const [],
  });

  final String id;
  final String ingredientId;
  final String name;
  final double? quantity;
  final String? unit;
  final String recipeId;
  final String recipeName;
  final String? recipeImage;
  bool isChecked;
  final DateTime addedAt;
  final List<SharedWithUser> sharedWith;

  String get displayText {
    final qty = quantity == null ? "" : "${quantity}";
    final unitStr = unit == null ? "" : " $unit";
    final prefix = (qty.isEmpty && unitStr.isEmpty) ? "" : "$qty$unitStr ";
    return "$prefix$name";
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "ingredientId": ingredientId,
      "name": name,
      "quantity": quantity,
      "unit": unit,
      "recipeId": recipeId,
      "recipeName": recipeName,
      "recipeImage": recipeImage,
      "isChecked": isChecked,
      "addedAt": addedAt.toIso8601String(),
      "sharedWith": sharedWith.map((u) => u.toJson()).toList(),
    };
  }

  factory ShoppingListItem.fromJson(Map<String, dynamic> json) {
    // Parse quantity - handle both number and string from backend
    double? parseQuantity(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    // Parse sharedWith array
    final List<SharedWithUser> sharedWith = [];
    final sharedWithData = json["sharedWith"];
    if (sharedWithData is List) {
      for (final item in sharedWithData) {
        if (item is Map) {
          try {
            sharedWith.add(SharedWithUser.fromJson(Map<String, dynamic>.from(item)));
          } catch (e) {
            // Skip invalid shared user
          }
        }
      }
    }

    return ShoppingListItem(
      id: json["id"].toString(),
      ingredientId: json["ingredientId"].toString(),
      name: json["name"].toString(),
      quantity: parseQuantity(json["quantity"]),
      unit: json["unit"]?.toString(),
      recipeId: json["recipeId"].toString(),
      recipeName: json["recipeName"].toString(),
      recipeImage: json["recipeImage"]?.toString(),
      isChecked: json["isChecked"] == true,
      addedAt: DateTime.parse(json["addedAt"].toString()),
      sharedWith: sharedWith,
    );
  }

  ShoppingListItem copyWith({
    String? id,
    String? ingredientId,
    String? name,
    double? quantity,
    String? unit,
    String? recipeId,
    String? recipeName,
    String? recipeImage,
    bool? isChecked,
    DateTime? addedAt,
    List<SharedWithUser>? sharedWith,
  }) {
    return ShoppingListItem(
      id: id ?? this.id,
      ingredientId: ingredientId ?? this.ingredientId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      recipeId: recipeId ?? this.recipeId,
      recipeName: recipeName ?? this.recipeName,
      recipeImage: recipeImage ?? this.recipeImage,
      isChecked: isChecked ?? this.isChecked,
      addedAt: addedAt ?? this.addedAt,
      sharedWith: sharedWith ?? this.sharedWith,
    );
  }
}

class GroupedShoppingItems {
  GroupedShoppingItems({
    required this.recipeId,
    required this.recipeName,
    this.recipeImage,
    required this.items,
  });

  final String recipeId;
  final String recipeName;
  final String? recipeImage;
  final List<ShoppingListItem> items;

  int get totalCount => items.length;
  int get checkedCount => items.where((i) => i.isChecked).length;
  bool get allChecked => items.isNotEmpty && items.every((i) => i.isChecked);
  bool get someChecked => items.any((i) => i.isChecked) && !allChecked;
}
