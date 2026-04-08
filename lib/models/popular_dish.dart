import '../models/menu_item.dart';

class PopularDish {
  final MenuItem item;
  final String restaurantId;
  final String restaurantName;

  PopularDish({
    required this.item,
    required this.restaurantId,
    required this.restaurantName,
  });
}
