import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../models/menu_item.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  String? _restaurantId;
  String? _restaurantName;

  List<CartItem> get items => List.unmodifiable(_items);
  String? get restaurantId => _restaurantId;
  String? get restaurantName => _restaurantName;
  
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  
  double get subtotal => _items.fold(0, (sum, item) => sum + item.subtotal);

  bool get isEmpty => _items.isEmpty;

  // Add item to cart
  void addItem({
    required MenuItem menuItem,
    String? selectedSize,
    List<MenuItemAddon> selectedAddons = const [],
  }) {
    // Auto-select first size if item has sizes but none selected
    String? finalSize = selectedSize;
    if (finalSize == null && menuItem.sizes != null && menuItem.sizes!.isNotEmpty) {
      finalSize = menuItem.sizes!.first.name;
    }
    
    // Calculate price based on selections
    double price = menuItem.price;
    
    // Use size price if available
    if (finalSize != null && menuItem.sizes != null) {
      final size = menuItem.sizes!.firstWhere(
        (s) => s.name == finalSize,
        orElse: () => MenuItemSize(name: '', price: 0),
      );
      price = size.price > 0 ? size.price : menuItem.price;
    }
    
    // Add addon prices
    for (final addon in selectedAddons) {
      price += addon.price;
    }

    final cartItem = CartItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      menuItemId: menuItem.id,
      name: menuItem.name,
      basePrice: menuItem.price,
      selectedSize: finalSize,
      selectedAddons: selectedAddons.map((a) => a.name).toList(),
      totalPrice: price,
      quantity: 1,
    );

    _items.add(cartItem);
    notifyListeners();
  }

  // Set restaurant context
  void setRestaurant(String id, String name) {
    if (_restaurantId != null && _restaurantId != id && _items.isNotEmpty) {
      // Different restaurant - need to clear cart first
      return;
    }
    _restaurantId = id;
    _restaurantName = name;
    notifyListeners();
  }

  // Update item quantity
  void updateQuantity(String cartItemId, int newQuantity) {
    final index = _items.indexWhere((item) => item.id == cartItemId);
    if (index == -1) return;

    if (newQuantity <= 0) {
      _items.removeAt(index);
    } else {
      _items[index] = _items[index].copyWith(quantity: newQuantity);
    }
    
    notifyListeners();
  }

  // Remove item
  void removeItem(String cartItemId) {
    _items.removeWhere((item) => item.id == cartItemId);
    notifyListeners();
  }

  // Clear cart
  void clear() {
    _items.clear();
    _restaurantId = null;
    _restaurantName = null;
    notifyListeners();
  }

  // Get items as order payload
  List<Map<String, dynamic>> toOrderItems() {
    return _items.map((item) => item.toOrderItem()).toList();
  }
}
