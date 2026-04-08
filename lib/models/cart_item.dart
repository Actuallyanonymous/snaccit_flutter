class CartItem {
  final String id; // Unique cart item ID
  final String menuItemId;
  final String name;
  final double basePrice;
  final String? selectedSize;
  final List<String> selectedAddons;
  final double totalPrice;
  final bool isExpress;
  int quantity;

  CartItem({
    required this.id,
    required this.menuItemId,
    required this.name,
    required this.basePrice,
    this.selectedSize,
    this.selectedAddons = const [],
    required this.totalPrice,
    this.isExpress = false,
    this.quantity = 1,
  });

  double get subtotal => totalPrice * quantity;

  CartItem copyWith({
    String? id,
    String? menuItemId,
    String? name,
    double? basePrice,
    String? selectedSize,
    List<String>? selectedAddons,
    double? totalPrice,
    bool? isExpress,
    int? quantity,
  }) {
    return CartItem(
      id: id ?? this.id,
      menuItemId: menuItemId ?? this.menuItemId,
      name: name ?? this.name,
      basePrice: basePrice ?? this.basePrice,
      selectedSize: selectedSize ?? this.selectedSize,
      selectedAddons: selectedAddons ?? this.selectedAddons,
      totalPrice: totalPrice ?? this.totalPrice,
      isExpress: isExpress ?? this.isExpress,
      quantity: quantity ?? this.quantity,
    );
  }

  /// Convert to format expected by Cloud Function (createOrderAndPay)
  /// The function expects: {id, size, addons: [], quantity}
  /// It recalculates prices server-side for security
  Map<String, dynamic> toOrderItem() {
    return {
      'id': menuItemId, // Menu item document ID for server-side lookup
      'size': selectedSize ?? '', // Size name (required by server)
      'addons': selectedAddons, // List of addon names
      'quantity': quantity,
      'isExpress': isExpress,
    };
  }
}
