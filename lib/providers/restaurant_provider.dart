import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/restaurant.dart';
import '../models/menu_item.dart';
import '../models/popular_dish.dart';

class RestaurantProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Restaurant> _restaurants = [];
  Restaurant? _selectedRestaurant;
  List<MenuItem> _menuItems = [];
  Map<String, List<MenuItem>> _menuByCategory = {};

  // Popular dishes across all restaurants
  List<PopularDish> _popularDishes = [];
  bool _isPopularLoading = false;

  // Separate loading flags so menu loading doesn't affect home screen
  bool _isLoading = false; // restaurants list loading
  bool _isMenuLoading = false; // menu loading
  String? _error;

  StreamSubscription? _menuSubscription;

  List<Restaurant> get restaurants => _restaurants;
  Restaurant? get selectedRestaurant => _selectedRestaurant;
  List<MenuItem> get menuItems => _menuItems;
  Map<String, List<MenuItem>> get menuByCategory => _menuByCategory;
  List<PopularDish> get popularDishes => _popularDishes;
  bool get isPopularLoading => _isPopularLoading;
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

    _firestore
        .collection('restaurants')
        .snapshots()
        .listen(
          (snapshot) {
            _restaurants = snapshot.docs
                .map((doc) => Restaurant.fromFirestore(doc))
                .toList();
            _isLoading = false;
            _error = null;
            notifyListeners();

            // Load popular dishes when restaurants are loaded
            _loadPopularDishes();
          },
          onError: (e) {
            _error = e.toString();
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  // Load one popular dish from each visible restaurant
  Future<void> _loadPopularDishes() async {
    final visible = _restaurants
        .where((r) => r.isVisible && r.isOperational)
        .toList();
    if (visible.isEmpty) return;

    _isPopularLoading = true;
    notifyListeners();

    final List<PopularDish> dishes = [];

    try {
      for (final restaurant in visible) {
        final snapshot = await _firestore
            .collection('restaurants')
            .doc(restaurant.id)
            .collection('menu')
            .where('isAvailable', isEqualTo: true)
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final item = MenuItem.fromFirestore(snapshot.docs.first);
          dishes.add(
            PopularDish(
              item: item,
              restaurantId: restaurant.id,
              restaurantName: restaurant.name,
            ),
          );
        }
      }

      _popularDishes = dishes;
    } catch (e) {
      debugPrint('Error loading popular dishes: $e');
    }

    _isPopularLoading = false;
    notifyListeners();
  }

  // Get suggestion items for cart (from currently selected restaurant)
  Future<List<MenuItem>> getSuggestions(
    String restaurantId,
    List<String> excludeIds,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('restaurants')
          .doc(restaurantId)
          .collection('menu')
          .where('isAvailable', isEqualTo: true)
          .limit(6)
          .get();

      return snapshot.docs
          .map((doc) => MenuItem.fromFirestore(doc))
          .where((item) => !excludeIds.contains(item.id))
          .take(3)
          .toList();
    } catch (e) {
      return [];
    }
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
