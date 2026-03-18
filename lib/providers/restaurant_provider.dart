import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/restaurant.dart';
import '../models/menu_item.dart';

class RestaurantProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<Restaurant> _restaurants = [];
  Restaurant? _selectedRestaurant;
  List<MenuItem> _menuItems = [];
  Map<String, List<MenuItem>> _menuByCategory = {};
  
  // Separate loading flags so menu loading doesn't affect home screen
  bool _isLoading = false;       // restaurants list loading
  bool _isMenuLoading = false;   // menu loading
  String? _error;
  
  StreamSubscription? _menuSubscription;

  List<Restaurant> get restaurants => _restaurants;
  Restaurant? get selectedRestaurant => _selectedRestaurant;
  List<MenuItem> get menuItems => _menuItems;
  Map<String, List<MenuItem>> get menuByCategory => _menuByCategory;
  bool get isLoading => _isLoading;
  bool get isMenuLoading => _isMenuLoading;
  String? get error => _error;

  // Get only operational AND visible restaurants
  List<Restaurant> get operationalRestaurants =>
      _restaurants.where((r) => r.isOperational && r.isVisible).toList();

  // Fetch all restaurants (realtime listener)
  void listenToRestaurants() {
    _isLoading = true;
    notifyListeners();

    _firestore.collection('restaurants').snapshots().listen(
      (snapshot) {
        _restaurants = snapshot.docs
            .map((doc) => Restaurant.fromFirestore(doc))
            .toList();
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // Select a restaurant
  void selectRestaurant(Restaurant restaurant) {
    _selectedRestaurant = restaurant;
    _menuItems = [];
    _menuByCategory = {};
    notifyListeners();
    
    // Load menu for this restaurant
    _loadMenu(restaurant.id);
  }

  // Clear selected restaurant
  void clearSelection() {
    _menuSubscription?.cancel();
    _selectedRestaurant = null;
    _menuItems = [];
    _menuByCategory = {};
    _isMenuLoading = false;
    notifyListeners();
  }

  // Load menu items for a restaurant
  void _loadMenu(String restaurantId) {
    // Cancel any previous menu subscription
    _menuSubscription?.cancel();
    
    _isMenuLoading = true;
    notifyListeners();

    _menuSubscription = _firestore
        .collection('restaurants')
        .doc(restaurantId)
        .collection('menu')
        .snapshots()
        .listen(
      (snapshot) {
        _menuItems = snapshot.docs
            .map((doc) => MenuItem.fromFirestore(doc))
            .where((item) => item.isAvailable)
            .toList();
        
        // Group by category
        _menuByCategory = {};
        for (final item in _menuItems) {
          final category = item.category ?? 'Other';
          _menuByCategory.putIfAbsent(category, () => []);
          _menuByCategory[category]!.add(item);
        }
        
        _isMenuLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _isMenuLoading = false;
        notifyListeners();
      },
    );
  }

  // Search menu items
  List<MenuItem> searchMenu(String query) {
    if (query.isEmpty) return _menuItems;
    
    final lowerQuery = query.toLowerCase();
    return _menuItems.where((item) {
      return item.name.toLowerCase().contains(lowerQuery) ||
          (item.description?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  @override
  void dispose() {
    _menuSubscription?.cancel();
    super.dispose();
  }
}
