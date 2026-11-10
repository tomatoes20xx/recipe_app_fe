import "../sharing/sharing_models.dart";

class ShoppingListItem {
  ShoppingListItem({
    required this.id,
    required this.ingredientId,
    required this.name,
    this.quantity,
    this.unit,
    this.recipeId,
    this.recipeName,
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
  /// Null for a manual item ("milk") added on the Manual tab.
  final String? recipeId;
  final String? recipeName;
  final String? recipeImage;
  bool isChecked;
  final DateTime addedAt;
  final List<SharedWithUser> sharedWith;

  bool get isManual => recipeId == null;

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
      recipeId: json["recipeId"]?.toString(),
      recipeName: json["recipeName"]?.toString(),
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


/// One line of the "By ingredient" view: every item with the same name
/// (ignoring case and spacing) across recipes, amounts added up per unit.
class MergedShoppingRow {
  MergedShoppingRow({required this.name, required this.items});

  final String name;
  final List<ShoppingListItem> items;

  List<String> get itemIds => [for (final item in items) item.id];
  bool get allChecked => items.every((i) => i.isChecked);

  /// Names of the recipes the items come from, without repeats.
  List<String> get recipeNames => {
        for (final item in items)
          if (item.recipeName != null) item.recipeName!,
      }.toList();

  /// Quantity per unit ("" for no unit), in the order units first appear.
  /// Items without a quantity count as nothing.
  Map<String, double> get totals {
    final totals = <String, double>{};
    for (final item in items) {
      final q = item.quantity;
      if (q == null) continue;
      final unit = item.unit?.trim() ?? "";
      totals[unit] = (totals[unit] ?? 0) + q;
    }
    return totals;
  }

  /// Merges [items] by name, keeping the order of each name's first item.
  static List<MergedShoppingRow> merge(List<ShoppingListItem> items) {
    final rows = <String, MergedShoppingRow>{};
    for (final item in items) {
      final key = item.name.trim().toLowerCase().replaceAll(RegExp(r"\s+"), " ");
      rows.putIfAbsent(key, () => MergedShoppingRow(name: item.name.trim(), items: [])).items.add(item);
    }
    return rows.values.toList();
  }
}
