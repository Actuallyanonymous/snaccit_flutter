import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus {
  awaitingPayment,
  pending,
  accepted,
  preparing,
  ready,
  completed,
  declined,
  failed,
  paymentFailed,
  paymentInitFailed,
}

class Order {
  final String id;
  final String userId;
  final String restaurantId;
  final String restaurantName;
  final List<OrderItem> items;
  final double subtotal;
  final double discount;
  final double total;
  final OrderStatus status;
  final String? arrivalTime;
  final String? orderNote;
  final String? couponCode;
  final int pointsRedeemed;
  final double pointsValue;
  final String? paymentMethod;
  final DateTime? createdAt;
  final bool hasReview;

  Order({
    required this.id,
    required this.userId,
    required this.restaurantId,
    required this.restaurantName,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.status,
    this.arrivalTime,
    this.orderNote,
    this.couponCode,
    this.pointsRedeemed = 0,
    this.pointsValue = 0,
    this.paymentMethod,
    this.createdAt,
    this.hasReview = false,
  });

  factory Order.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Order(
      id: doc.id,
      userId: data['userId'] ?? '',
      restaurantId: data['restaurantId'] ?? '',
      restaurantName: data['restaurantName'] ?? '',
      items: (data['items'] as List<dynamic>?)
              ?.map((i) => OrderItem.fromMap(i as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (data['discount'] as num?)?.toDouble() ?? 0.0,
      total: (data['total'] as num?)?.toDouble() ?? 0.0,
      status: _parseStatus(data['status']),
      arrivalTime: data['arrivalTime'],
      orderNote: data['orderNote'],
      couponCode: data['couponCode'],
      pointsRedeemed: data['pointsRedeemed'] ?? 0,
      pointsValue: (data['pointsValue'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: data['paymentMethod'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      hasReview: data['hasReview'] ?? false,
    );
  }

  static OrderStatus _parseStatus(String? status) {
    switch (status) {
      case 'awaiting_payment':
        return OrderStatus.awaitingPayment;
      case 'pending':
        return OrderStatus.pending;
      case 'accepted':
        return OrderStatus.accepted;
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready':
        return OrderStatus.ready;
      case 'completed':
        return OrderStatus.completed;
      case 'declined':
        return OrderStatus.declined;
      case 'failed':
        return OrderStatus.failed;
      case 'payment_failed':
        return OrderStatus.paymentFailed;
      case 'payment_init_failed':
        return OrderStatus.paymentInitFailed;
      default:
        return OrderStatus.pending;
    }
  }

  String get statusDisplay {
    switch (status) {
      case OrderStatus.awaitingPayment:
        return 'Awaiting Payment';
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.accepted:
        return 'Accepted';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.ready:
        return 'Ready for Pickup';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.declined:
        return 'Declined';
      case OrderStatus.failed:
        return 'Failed';
      case OrderStatus.paymentFailed:
        return 'Payment Failed';
      case OrderStatus.paymentInitFailed:
        return 'Payment Failed';
    }
  }

  bool get isActive =>
      status == OrderStatus.awaitingPayment ||
      status == OrderStatus.pending ||
      status == OrderStatus.accepted ||
      status == OrderStatus.preparing ||
      status == OrderStatus.ready;
}

class OrderItem {
  final String name;
  final double price;
  final int quantity;
  final String? size;
  final List<String>? addons;

  OrderItem({
    required this.name,
    required this.price,
    required this.quantity,
    this.size,
    this.addons,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      name: map['name'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      quantity: map['quantity'] ?? 1,
      size: map['size'],
      addons: (map['addons'] as List<dynamic>?)?.cast<String>(),
    );
  }
}
