import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:cloud_functions/cloud_functions.dart';
import '../models/order.dart';

class OrderProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Order> _orders = [];
  Order? _currentOrder;
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _ordersSubscription;
  StreamSubscription? _orderSubscription;

  List<Order> get orders => _orders;
  Order? get currentOrder => _currentOrder;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get active orders (pending, accepted, preparing, ready)
  List<Order> get activeOrders => _orders.where((o) => o.isActive).toList();

  // Get past orders (completed, declined, failed)
  List<Order> get pastOrders => _orders.where((o) => !o.isActive).toList();

  // Listen to user's orders
  void listenToOrders(String userId) {
    _ordersSubscription?.cancel();

    _ordersSubscription = _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen(
          (snapshot) {
            _orders = snapshot.docs
                .map((doc) => Order.fromFirestore(doc))
                .toList();
            notifyListeners();
          },
          onError: (e) {
            _error = e.toString();
            notifyListeners();
          },
        );
  }

  // Listen to a specific order (for payment status tracking)
  void listenToOrder(String orderId) {
    _orderSubscription?.cancel();

    _orderSubscription = _firestore
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .listen(
          (doc) {
            if (doc.exists) {
              _currentOrder = Order.fromFirestore(doc);
              notifyListeners();
            }
          },
          onError: (e) {
            _error = e.toString();
            notifyListeners();
          },
        );
  }

  // Stop listening to specific order
  void stopListeningToOrder() {
    _orderSubscription?.cancel();
    _orderSubscription = null;
    _currentOrder = null;
    notifyListeners();
  }

  // Place order (calls Cloud Function)
  Future<Map<String, dynamic>> placeOrder({
    required String restaurantId,
    required List<Map<String, dynamic>> items,
    required String arrivalTime,
    required String userName,
    required String userPhone,
    String? couponCode,
    bool usePoints = false,
    String paymentMethod = 'phonepe',
    String? orderNote,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Call Cloud Function to create order and initiate payment
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-south2',
      ).httpsCallable('createOrderAndPay');

      final result = await callable.call({
        'restaurantId': restaurantId,
        'items': items,
        'arrivalTime': arrivalTime,
        'userName': userName,
        'userPhone': userPhone,
        'couponCode': couponCode,
        'usePoints': usePoints,
        'paymentMethod': paymentMethod,
        'orderNote': orderNote,
        'platform': 'mobile',
      });

      _isLoading = false;
      notifyListeners();

      return Map<String, dynamic>.from(result.data as Map);
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Submit review for an order
  Future<void> submitReview({
    required String orderId,
    required String restaurantId,
    required int rating,
    required String comment,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Add review to restaurant's reviews collection
      await _firestore
          .collection('restaurants')
          .doc(restaurantId)
          .collection('reviews')
          .add({
            'orderId': orderId,
            'rating': rating,
            'comment': comment,
            'createdAt': FieldValue.serverTimestamp(),
          });

      // Mark order as reviewed
      await _firestore.collection('orders').doc(orderId).update({
        'hasReview': true,
      });

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Dispose subscriptions
  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _orderSubscription?.cancel();
    super.dispose();
  }
}
