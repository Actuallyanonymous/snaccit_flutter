import 'package:cloud_firestore/cloud_firestore.dart';

class Restaurant {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? address;
  final String? openingTime;
  final String? closingTime;
  final bool isOperational;
  final bool isCodAvailable;
  final bool isVisible;
  final String? ownerUID;
  final double? rating;
  final int? reviewCount;

  Restaurant({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.address,
    this.openingTime,
    this.closingTime,
    this.isOperational = true,
    this.isCodAvailable = false,
    this.isVisible = true,
    this.ownerUID,
    this.rating,
    this.reviewCount,
  });

  factory Restaurant.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Restaurant(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      imageUrl: data['imageUrl'],
      address: data['address'],
      openingTime: data['openingTime'],
      closingTime: data['closingTime'],
      isOperational: data['isOperational'] ?? true,
      isCodAvailable: data['codEnabled'] ?? false,
      isVisible: data['isVisible'] ?? true,
      ownerUID: data['ownerUID'],
      rating: (data['rating'] as num?)?.toDouble(),
      reviewCount: data['reviewCount'],
    );
  }

  /// Whether the restaurant is open — only based on owner's toggle (isOperational),
  /// NOT on opening/closing times. Time only affects available slots in checkout.
  bool get isOpen => isOperational;

  /// Whether the current time is within the restaurant's operating hours.
  /// Returns true if no hours are set (assume always open by time).
  bool get isCurrentlyInHours {
    if (openingTime == null || closingTime == null) return true;
    try {
      final now = DateTime.now();
      final openParts = openingTime!.split(':');
      final closeParts = closingTime!.split(':');
      final open = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(openParts[0]),
        int.parse(openParts[1]),
      );
      final close = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(closeParts[0]),
        int.parse(closeParts[1]),
      );
      return now.isAfter(open) && now.isBefore(close);
    } catch (_) {
      return true; // If parsing fails, assume open
    }
  }

  /// Whether the restaurant is closed due to time (outside business hours)
  /// but NOT because the owner toggled it off.
  bool get isTimeClosed => isOperational && !isCurrentlyInHours;
}
