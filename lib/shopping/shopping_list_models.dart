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
