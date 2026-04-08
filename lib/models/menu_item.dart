import 'package:cloud_firestore/cloud_firestore.dart';

class MenuItem {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final double price;
  final String? category;
  final bool isAvailable;
  final List<MenuItemSize>? sizes;
  final List<MenuItemAddon>? addons;
  final bool isVeg;
  final bool isExpress;

  MenuItem({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.price,
    this.category,
    this.isAvailable = true,
    this.sizes,
    this.addons,
    this.isVeg = false,
    this.isExpress = false,
  });

  factory MenuItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    List<MenuItemSize>? parsedSizes;
    try {
      final rawSizes = data['sizes'];
      if (rawSizes is List) {
        parsedSizes = rawSizes
            .whereType<Map>()
            .map(
              (s) => MenuItemSize.fromMap(Map<String, dynamic>.from(s)),
            )
            .toList();
      }
    } catch (_) {
      parsedSizes = null;
    }

    List<MenuItemAddon>? parsedAddons;
    try {
      final rawAddons = data['addons'];
      if (rawAddons is List) {
        parsedAddons = rawAddons
            .whereType<Map>()
            .map(
              (a) => MenuItemAddon.fromMap(Map<String, dynamic>.from(a)),
            )
            .toList();
      }
    } catch (_) {
      parsedAddons = null;
    }

    return MenuItem(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      imageUrl: data['imageUrl'],
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      category: data['category'],
      isAvailable: data['isAvailable'] ?? true,
      sizes: parsedSizes,
      addons: parsedAddons,
      isVeg: data['isVeg'] ?? false,
      isExpress: data['isExpress'] ?? false,
    );
  }
}

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

class MenuItemSize {
  final String name;
  final double price;

  MenuItemSize({required this.name, required this.price});

  factory MenuItemSize.fromMap(Map<String, dynamic> map) {
    return MenuItemSize(
      name: map['name']?.toString() ?? '',
      price: _parseDouble(map['price']),
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'price': price};
}

class MenuItemAddon {
  final String name;
  final double price;

  MenuItemAddon({required this.name, required this.price});

  factory MenuItemAddon.fromMap(Map<String, dynamic> map) {
    return MenuItemAddon(
      name: map['name']?.toString() ?? '',
      price: _parseDouble(map['price']),
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'price': price};
}
