import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/restaurant_provider.dart';
import '../providers/order_provider.dart';
import '../models/menu_item.dart';
import 'auth_screen.dart';
import 'payment_status_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  // ─── Cart State ───
  String _currentFact = '';
  List<MenuItem> _suggestions = [];
  bool _suggestionsLoaded = false;

  static const _foodFacts = [
    'The world\'s largest pizza was 131 ft wide, made in Rome!',
    'Americans eat about 50 billion burgers a year!',
    'Instant ramen was invented in 1958 by Momofuku Ando!',
    'The donut hole was invented by a 15-year-old in 1847!',
    'Tacos date back to 18th century Mexican silver mines!',
    'Adding salt to lemonade actually makes it taste sweeter!',
    'Japan has a museum dedicated entirely to instant ramen!',
    'The first hamburger was served in 1895 in Connecticut!',
    'About 3 billion pizzas are sold in the US every year!',
    'The oldest noodles ever found were 4,000 years old!',
  ];

  // ─── Checkout State ───
  // Empty string = nothing pre-selected (user must choose)
  String _selectedTime = '';
  String _paymentMethod = 'phonepe';
  final _noteController = TextEditingController();
  final _couponController = TextEditingController();
  bool _usePoints = false;
  bool _isPlacingOrder = false;

  double _couponDiscount = 0;
  String? _couponError;
  Map<String, dynamic>? _appliedCoupon;
  bool _isValidatingCoupon = false;

  // ASAP adds ₹1 as a soft nudge to encourage pre-ordering.
  // Note: the backend determines the actual payment amount — update the
  // cloud function to add this fee when arrivalTime == 'ASAP' if needed.
  static const double _asapFee = 1.0;

  @override
  void initState() {
    super.initState();
    _currentFact = _foodFacts[Random().nextInt(_foodFacts.length)];
    _loadSuggestions();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  // ─── Cart Methods ───

  void _loadSuggestions() async {
    final cart = context.read<CartProvider>();
    if (cart.restaurantId == null) return;

    final existingIds = cart.items.map((i) => i.menuItemId).toList();
    final provider = context.read<RestaurantProvider>();
    final suggestions = await provider.getSuggestions(
      cart.restaurantId!,
      existingIds,
    );

    if (mounted) {
      setState(() {
        _suggestions = suggestions;
        _suggestionsLoaded = true;
      });
    }
  }

  void _addSuggestion(MenuItem item) {
    HapticFeedback.lightImpact();
    context.read<CartProvider>().addItem(menuItem: item);
    setState(() {
      _suggestions.removeWhere((s) => s.id == item.id);
    });
  }

  // ─── Checkout Methods ───

  /// Returns only scheduled time slots (no ASAP — that's handled separately).
  List<String> _generateTimeSlots() {
    final provider = context.read<RestaurantProvider>();
    final restaurant = provider.selectedRestaurant;

    if (restaurant?.openingTime == null || restaurant?.closingTime == null) {
      return [];
    }

    final now = DateTime.now();
    final openParts = restaurant!.openingTime!.split(':');
    final closeParts = restaurant.closingTime!.split(':');

    final openingTime = DateTime(
      now.year, now.month, now.day,
      int.parse(openParts[0]), int.parse(openParts[1]),
    );
    final closingTime = DateTime(
      now.year, now.month, now.day,
      int.parse(closeParts[0]), int.parse(closeParts[1]),
    );

    if (now.isAfter(closingTime) || now.isAtSameMomentAs(closingTime)) {
      return [];
    }

    const intervalMinutes = 5;
    const minimumLeadTimeMinutes = 15;

    var startTime = now.add(const Duration(minutes: minimumLeadTimeMinutes));
    final remainder = startTime.minute % intervalMinutes;
    if (remainder != 0) {
      startTime = DateTime(
        startTime.year, startTime.month, startTime.day,
        startTime.hour,
        startTime.minute + (intervalMinutes - remainder),
      );
    }

    if (startTime.isBefore(openingTime)) startTime = openingTime;

    final slots = <String>[];
    while (startTime.isBefore(closingTime)) {
      slots.add(DateFormat('h:mm a').format(startTime));
      startTime = startTime.add(const Duration(minutes: intervalMinutes));
    }

    return slots;
  }

  /// True only when the restaurant has hours configured AND is past closing time.
  bool _isRestaurantClosed() {
    final restaurant =
        context.read<RestaurantProvider>().selectedRestaurant;
    if (restaurant?.closingTime == null) return false;
    final now = DateTime.now();
    final parts = restaurant!.closingTime!.split(':');
    final closing = DateTime(
      now.year, now.month, now.day,
      int.parse(parts[0]), int.parse(parts[1]),
    );
    return now.isAfter(closing) || now.isAtSameMomentAs(closing);
  }

  double get _asapSurcharge => _selectedTime == 'ASAP' ? _asapFee : 0.0;

  double get _pointsDiscountValue {
    if (!_usePoints) return 0;
    final auth = context.read<AuthProvider>();
    final points = auth.userProfile?.points ?? 0;
    if (points <= 0) return 0;
    final cart = context.read<CartProvider>();
    final potential = (points / 10).floorToDouble();
    final remaining =
        (cart.subtotal + _asapSurcharge - _couponDiscount).clamp(0.0, double.infinity);
    return potential.clamp(0.0, remaining).toDouble();
  }

  double get _grandTotal {
    final cart = context.read<CartProvider>();
    return (cart.subtotal + _asapSurcharge - _couponDiscount - _pointsDiscountValue)
        .clamp(0.0, double.infinity)
        .toDouble();
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _isValidatingCoupon = true;
      _couponError = null;
      _couponDiscount = 0;
      _appliedCoupon = null;
    });

    try {
      final cart = context.read<CartProvider>();
      final auth = context.read<AuthProvider>();
      final subtotal = cart.subtotal;

      final couponSnap = await FirebaseFirestore.instance
          .collection('coupons')
          .doc(code)
          .get();

      if (!couponSnap.exists) {
        setState(() => _couponError = 'Invalid coupon code.');
        return;
      }

      final coupon = couponSnap.data()!;
      final now = DateTime.now();

      if (coupon['isActive'] == false) {
        setState(() => _couponError = 'This coupon is no longer active.');
        return;
      }

      if (coupon['expiryDate'] != null) {
        final expiry = (coupon['expiryDate'] as Timestamp).toDate();
        if (now.isAfter(expiry)) {
          setState(() => _couponError = 'This coupon has expired.');
          return;
        }
      }

      final minOrder = (coupon['minOrderValue'] as num?)?.toDouble() ?? 0;
      if (subtotal < minOrder) {
        setState(
          () => _couponError =
              'Minimum order of ₹${minOrder.toStringAsFixed(0)} required.',
        );
        return;
      }

      if (coupon['usageLimit'] == 'once' && auth.firebaseUser != null) {
        final previousOrders = await FirebaseFirestore.instance
            .collection('orders')
            .where('userId', isEqualTo: auth.firebaseUser!.uid)
            .where('couponCode', isEqualTo: code)
            .where(
              'status',
              whereIn: ['pending', 'accepted', 'preparing', 'ready', 'completed'],
            )
            .limit(1)
            .get();

        if (previousOrders.docs.isNotEmpty) {
          setState(() => _couponError = 'You have already used this coupon.');
          return;
        }
      }

      double calculatedDiscount = 0;
      if (coupon['type'] == 'fixed') {
        calculatedDiscount = (coupon['value'] as num).toDouble();
      } else if (coupon['type'] == 'percentage') {
        calculatedDiscount = (subtotal * (coupon['value'] as num).toDouble()) / 100;
      }

      setState(() {
        _couponDiscount = calculatedDiscount.clamp(0, subtotal);
        _appliedCoupon = {'code': code, ...coupon};
      });
    } catch (e) {
      setState(() => _couponError = 'Could not validate coupon. Try again.');
    } finally {
      setState(() => _isValidatingCoupon = false);
    }
  }

  Future<void> _placeOrder() async {
    if (_selectedTime.isEmpty) return;

    final cart = context.read<CartProvider>();
    final auth = context.read<AuthProvider>();
    final orders = context.read<OrderProvider>();

    if (cart.restaurantId == null) return;

    setState(() => _isPlacingOrder = true);

    try {
      final result = await orders.placeOrder(
        restaurantId: cart.restaurantId!,
        items: cart.toOrderItems(),
        arrivalTime: _selectedTime,
        userName: auth.userProfile?.name ?? 'Customer',
        userPhone: auth.firebaseUser?.phoneNumber ?? '',
        paymentMethod: _paymentMethod,
        usePoints: _usePoints,
        couponCode: _appliedCoupon != null
            ? _appliedCoupon!['code'] as String
            : null,
        orderNote: _noteController.text.isNotEmpty
            ? _noteController.text
            : null,
      );

      final redirectUrl = result['redirectUrl'] as String?;
      final orderId = result['orderId'] as String?;
      final capturedGrandTotal = _grandTotal;

      if (mounted) setState(() => _isPlacingOrder = false);

      cart.clear();

      if (mounted) {
        if (_paymentMethod == 'cod' || capturedGrandTotal == 0) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => PaymentStatusScreen(
                orderId: orderId ?? _extractOrderId(redirectUrl),
              ),
            ),
            (route) => route.isFirst,
          );
        } else if (redirectUrl != null && redirectUrl.isNotEmpty) {
          final payRedirectUrl =
              'https://www.snaccit.com/pay-redirect.html?url=${Uri.encodeComponent(redirectUrl)}';

          final uri = Uri.parse(payRedirectUrl);
          try {
            await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
          } catch (e) {
            debugPrint('Could not launch external browser: $e');
          }

          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => PaymentStatusScreen(
                  orderId: orderId ?? _extractOrderId(redirectUrl),
                ),
              ),
              (route) => route.isFirst,
            );
          }
        } else {
          Navigator.of(context).popUntil((route) => route.isFirst);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Order created. Check order history for status.'),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
            ),
          );
        }
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() => _isPlacingOrder = false);
        final errorMsg =
            (e.details as String?) ?? e.message ?? 'Something went wrong. Please try again.';
        _showErrorSnack(errorMsg);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPlacingOrder = false);
        String errorMsg = 'Something went wrong. Please try again.';
        final eStr = e.toString();
        final bracketMatch = RegExp(r'\] (.+)$').firstMatch(eStr);
        if (bracketMatch != null) {
          errorMsg = bracketMatch.group(1)!;
        } else if (eStr.contains('Exception: ')) {
          errorMsg = eStr.replaceAll('Exception: ', '');
        }
        _showErrorSnack(errorMsg);
      }
    }
  }

  void _showErrorSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _extractOrderId(String? url) {
    if (url == null) return '';
    return Uri.tryParse(url)?.queryParameters['orderId'] ?? '';
  }

  String _getDiscountSummary(AuthProvider auth) {
    final parts = <String>[];
    if (_appliedCoupon != null) {
      parts.add('Coupon "${_appliedCoupon!['code']}" (-₹${_couponDiscount.toStringAsFixed(0)})');
    }
    if (_usePoints && _pointsDiscountValue > 0) {
      parts.add('Points (-₹${_pointsDiscountValue.toStringAsFixed(0)})');
    }
    if (parts.isEmpty) {
      final hasPoints = (auth.userProfile?.points ?? 0) > 0;
      return hasPoints ? 'Apply coupon or use points' : 'Apply a coupon code';
    }
    return parts.join(' · ');
  }

  // ─── Time Slot Picker Modal (redesigned) ───
  void _showTimeSlotPicker(List<String> timeSlots) {
    String tempSelected = _selectedTime;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.72,
          ),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textHint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      color: AppTheme.primaryGreen,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'When to pick up?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── ASAP (separate, subtle amber style) ───
                      GestureDetector(
                        onTap: () => setModalState(() => tempSelected = 'ASAP'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: tempSelected == 'ASAP'
                                ? const Color(0xFFFFF7ED)
                                : AppTheme.backgroundLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: tempSelected == 'ASAP'
                                  ? const Color(0xFFF97316)
                                  : AppTheme.border.withValues(alpha: 0.4),
                              width: tempSelected == 'ASAP' ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.bolt_rounded,
                                  color: Color(0xFFF97316),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'ASAP — Right Now',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Not recommended. Delay expected.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFD97706), // darker amber
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // +₹1 badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED),
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(
                                    color: const Color(0xFFF97316).withValues(alpha: 0.45),
                                  ),
                                ),
                                child: const Text(
                                  '+₹1',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFF97316),
                                  ),
                                ),
                              ),
                              if (tempSelected == 'ASAP') ...[
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFFF97316),
                                  size: 20,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ─── Time slots grid ───
                      if (timeSlots.isNotEmpty) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Container(height: 1, color: AppTheme.divider),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'or schedule a time',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(height: 1, color: AppTheme.divider),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: timeSlots.map((slot) {
                            final isSelected = tempSelected == slot;
                            return GestureDetector(
                              onTap: () =>
                                  setModalState(() => tempSelected = slot),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width:
                                    (MediaQuery.of(context).size.width - 40 - 20) / 3,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.primaryGreen
                                      : AppTheme.surfaceWhite,
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.primaryGreen
                                        : AppTheme.border.withValues(alpha: 0.5),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? AppTheme.shadowGreen
                                      : AppTheme.shadowCard,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  slot,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? Colors.white
                                        : AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // Confirm button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: SafeArea(
                  child: GestureDetector(
                    onTap: tempSelected.isEmpty
                        ? null
                        : () {
                            setState(() => _selectedTime = tempSelected);
                            Navigator.pop(context);
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: tempSelected.isNotEmpty
                            ? AppTheme.buttonGradient
                            : null,
                        color: tempSelected.isEmpty
                            ? AppTheme.primaryGreen.withValues(alpha: 0.4)
                            : null,
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: tempSelected.isNotEmpty
                            ? AppTheme.shadowGreen
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        tempSelected.isEmpty
                            ? 'Select a time above'
                            : 'Confirm · $tempSelected',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Discounts Modal ───
  void _showDiscountsModal(AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: AppTheme.surfaceWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textHint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_offer_rounded,
                        color: AppTheme.primaryGreen,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Discounts & Offers',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Coupon field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Coupon Code',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundLight,
                          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                          border: Border.all(
                            color: AppTheme.border.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _couponController,
                                textCapitalization: TextCapitalization.characters,
                                enabled: _appliedCoupon == null,
                                onChanged: (_) => setModalState(() {}),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  letterSpacing: 1,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Enter code',
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              child: _appliedCoupon != null
                                  ? TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _appliedCoupon = null;
                                          _couponDiscount = 0;
                                          _couponController.clear();
                                        });
                                        setModalState(() {});
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppTheme.errorRed,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                        shape: const StadiumBorder(),
                                      ),
                                      child: const Text(
                                        'Remove',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                      ),
                                    )
                                  : TextButton(
                                      onPressed: (_isValidatingCoupon ||
                                              _couponController.text.trim().isEmpty)
                                          ? null
                                          : () async {
                                              await _applyCoupon();
                                              setModalState(() {});
                                            },
                                      style: TextButton.styleFrom(
                                        backgroundColor: AppTheme.primaryGreen,
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor:
                                            AppTheme.primaryGreen.withValues(alpha: 0.4),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 10,
                                        ),
                                        shape: const StadiumBorder(),
                                      ),
                                      child: _isValidatingCoupon
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text(
                                              'Apply',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      if (_couponError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _couponError!,
                            style: TextStyle(
                              color: AppTheme.errorRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      if (_appliedCoupon != null && _couponError == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                size: 14,
                                color: AppTheme.primaryGreen,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Coupon "${_appliedCoupon!['code']}" applied! (-₹${_couponDiscount.toStringAsFixed(0)})',
                                style: const TextStyle(
                                  color: AppTheme.primaryGreen,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Points
                if (auth.userProfile != null && (auth.userProfile!.points) > 0) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _usePoints = !_usePoints);
                        setModalState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _usePoints
                              ? AppTheme.emerald50
                              : AppTheme.backgroundLight,
                          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                          border: Border.all(
                            color: _usePoints
                                ? AppTheme.primaryGreen
                                : AppTheme.border.withValues(alpha: 0.5),
                            width: _usePoints ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _usePoints
                                      ? AppTheme.primaryGreen
                                      : AppTheme.textHint,
                                  width: 2,
                                ),
                                color: _usePoints
                                    ? AppTheme.primaryGreen
                                    : Colors.transparent,
                              ),
                              child: _usePoints
                                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Use ${auth.userProfile!.points} points',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: _usePoints
                                          ? AppTheme.primaryGreenDark
                                          : AppTheme.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Save ₹${(auth.userProfile!.points / 10).toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _usePoints
                                          ? AppTheme.primaryGreen
                                          : AppTheme.textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.card_giftcard,
                              size: 22,
                              color: AppTheme.primaryGreen,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: SafeArea(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: AppTheme.buttonGradient,
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: AppTheme.shadowGreen,
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Done',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final timeSlots = _generateTimeSlots();
    final isClosed = _isRestaurantClosed();

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWhite,
        title: const Text('Cart'),
        actions: [
          Consumer<CartProvider>(
            builder: (context, cart, _) {
              if (cart.isEmpty) return const SizedBox.shrink();
              return TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius2XL),
                      ),
                      title: const Text('Clear Cart?'),
                      content: const Text('Remove all items from your cart?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            cart.clear();
                            Navigator.pop(ctx);
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Clear',
                            style: TextStyle(
                              color: AppTheme.errorRed,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                child: Text(
                  'Clear All',
                  style: TextStyle(
                    color: AppTheme.errorRed.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<CartProvider>(
        builder: (context, cart, _) {
          if (cart.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppTheme.emerald50,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.shopping_cart_outlined,
                        size: 44,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Your cart is empty',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Add items from a restaurant to get started',
                    style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      ),
                    ),
                    child: const Text('Browse Restaurants'),
                  ),
                ],
              ).animate().fadeIn(),
            );
          }

          final subtotal = cart.subtotal;
          final asapFee = _asapSurcharge;
          final pointsDiscount = _pointsDiscountValue;
          final grandTotal = _grandTotal;
          final canPlaceOrder =
              !_isPlacingOrder && _selectedTime.isNotEmpty && !isClosed;

          return Column(
            children: [
              // Restaurant header
              if (cart.restaurantName != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: const BoxDecoration(
                    gradient: AppTheme.cartHeaderGradient,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.storefront,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your Order',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'from ${cart.restaurantName}',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          '${cart.itemCount} items',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // ─── Cart Items ───
                    ...List.generate(cart.items.length, (index) {
                      final item = cart.items[index];
                      return AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceWhite,
                                borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                                border: Border.all(
                                  color: AppTheme.border.withValues(alpha: 0.3),
                                ),
                                boxShadow: AppTheme.shadowCard,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        if (item.selectedSize != null ||
                                            item.selectedAddons.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text(
                                              [
                                                if (item.selectedSize != null)
                                                  item.selectedSize,
                                                ...item.selectedAddons,
                                              ].join(' · '),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.textMuted,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '₹${item.subtotal.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppTheme.emerald50,
                                      borderRadius: BorderRadius.circular(100),
                                      border: Border.all(
                                        color: AppTheme.primaryGreenLight,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _QuantityButton(
                                          icon: item.quantity == 1
                                              ? Icons.delete_outline
                                              : Icons.remove,
                                          color: item.quantity == 1
                                              ? AppTheme.errorRed
                                              : AppTheme.primaryGreen,
                                          onTap: () => cart.updateQuantity(
                                            item.id,
                                            item.quantity - 1,
                                          ),
                                        ),
                                        Container(
                                          width: 32,
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${item.quantity}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                              color: AppTheme.primaryGreen,
                                            ),
                                          ),
                                        ),
                                        _QuantityButton(
                                          icon: Icons.add,
                                          color: AppTheme.primaryGreen,
                                          onTap: () => cart.updateQuantity(
                                            item.id,
                                            item.quantity + 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .animate(delay: Duration(milliseconds: 60 * index))
                          .fadeIn(duration: 300.ms)
                          .slideX(begin: 0.03);
                    }),

                    const SizedBox(height: 8),

                    // ─── Food Fact ───
                    _buildFoodFactCard(),

                    // ─── Suggestions ───
                    if (_suggestionsLoaded && _suggestions.isNotEmpty)
                      _buildSuggestionsSection(cart),

                    const SizedBox(height: 16),

                    // ─── Pre-Order Advertisement Banner ───
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                        border: Border.all(color: AppTheme.primaryGreenLight.withValues(alpha: 0.5)),
                        boxShadow: AppTheme.shadowSm,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.timer_outlined, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pro Tip: Schedule & Save Time!',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryGreenDark,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Pre-order to skip the line. It helps us serve you fresh & fast.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate(delay: 50.ms).fadeIn(duration: 300.ms).slideY(begin: -0.05),

                    // ─── Pickup Time ───
                    _buildPickupTimeSection(timeSlots, isClosed)
                        .animate(delay: 100.ms)
                        .fadeIn(duration: 300.ms),

                    const SizedBox(height: 14),

                    // ─── Special Request ───
                    _buildSection(
                      icon: Icons.edit_note,
                      title: 'Special Request',
                      subtitle: 'Optional',
                      child: TextField(
                        controller: _noteController,
                        maxLines: 2,
                        maxLength: 200,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Any special instructions...',
                          filled: true,
                          fillColor: AppTheme.backgroundLight,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            borderSide: const BorderSide(
                              color: AppTheme.primaryGreen,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.all(14),
                          counterStyle: TextStyle(
                            color: AppTheme.textHint,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ).animate(delay: 150.ms).fadeIn(duration: 300.ms),

                    const SizedBox(height: 14),

                    // ─── Discounts ───
                    GestureDetector(
                      onTap: () => _showDiscountsModal(auth),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceWhite,
                          borderRadius: BorderRadius.circular(AppTheme.radius2XL),
                          border: Border.all(
                            color: AppTheme.border.withValues(alpha: 0.3),
                          ),
                          boxShadow: AppTheme.shadowCard,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.emerald50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.local_offer_rounded,
                                color: AppTheme.primaryGreen,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Discounts & Offers',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _getDiscountSummary(auth),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: (_couponDiscount > 0 ||
                                              (_usePoints && pointsDiscount > 0))
                                          ? AppTheme.primaryGreen
                                          : AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_couponDiscount > 0 ||
                                (_usePoints && pointsDiscount > 0))
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.emerald50,
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(color: AppTheme.primaryGreenLight),
                                ),
                                child: Text(
                                  '-₹${(_couponDiscount + pointsDiscount).toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                              )
                            else
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppTheme.textHint,
                                size: 24,
                              ),
                          ],
                        ),
                      ),
                    ).animate(delay: 200.ms).fadeIn(duration: 300.ms),

                    const SizedBox(height: 14),

                    // ─── Bill Summary ───
                    _buildBillSummary(
                      cart: cart,
                      subtotal: subtotal,
                      asapFee: asapFee,
                      couponDiscount: _couponDiscount,
                      pointsDiscount: pointsDiscount,
                      grandTotal: grandTotal,
                    ).animate(delay: 250.ms).fadeIn(duration: 400.ms),

                    const SizedBox(height: 14),

                    // ─── Payment Method ───
                    Builder(
                      builder: (context) {
                        final restaurant =
                            context.read<RestaurantProvider>().selectedRestaurant;
                        final codAvailable = restaurant?.isCodAvailable ?? false;
                        return _buildSection(
                          icon: Icons.payment,
                          title: 'Payment Method',
                          child: Column(
                            children: [
                              _buildPaymentOption(
                                title: 'PhonePe / UPI',
                                subtitle: 'Pay online securely',
                                icon: Icons.smartphone,
                                value: 'phonepe',
                                color: const Color(0xFF5F259F),
                              ),
                              if (codAvailable) ...[
                                const SizedBox(height: 8),
                                _buildPaymentOption(
                                  title: 'Cash on Pickup',
                                  subtitle: 'Pay when you arrive',
                                  icon: Icons.payments_outlined,
                                  value: 'cod',
                                  color: AppTheme.primaryGreen,
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ).animate(delay: 300.ms).fadeIn(duration: 300.ms),

                    const SizedBox(height: 100),
                  ],
                ),
              ),

              // ─── Bottom Bar ───
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWhite,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B7E6A).withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Time reminder if nothing selected
                      if (_selectedTime.isEmpty && !isClosed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 14,
                                color: AppTheme.amber600,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Choose a pickup time to place your order',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.amber600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      GestureDetector(
                        onTap: () {
                          if (!auth.isLoggedIn) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AuthScreen()),
                            );
                            return;
                          }
                          if (canPlaceOrder) _placeOrder();
                        },
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: canPlaceOrder ? AppTheme.buttonGradient : null,
                            color: canPlaceOrder
                                ? null
                                : AppTheme.primaryGreen.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: canPlaceOrder ? AppTheme.shadowGreen : null,
                          ),
                          alignment: Alignment.center,
                          child: _isPlacingOrder
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.shopping_bag_rounded,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isClosed
                                          ? 'Restaurant Closed'
                                          : _selectedTime.isEmpty
                                              ? 'Select Pickup Time'
                                              : grandTotal == 0
                                                  ? 'Confirm Order (₹0)'
                                                  : _paymentMethod == 'cod'
                                                      ? 'Place Order · ₹${grandTotal.toStringAsFixed(0)} (COD)'
                                                      : 'Place Order · ₹${grandTotal.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Pickup Time Section ───
  Widget _buildPickupTimeSection(List<String> timeSlots, bool isClosed) {
    if (isClosed) {
      return _buildSection(
        icon: Icons.schedule,
        title: 'Pickup Time',
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.errorRed.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.schedule, color: AppTheme.errorRed, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Builder(
                  builder: (_) {
                    final r = context.read<RestaurantProvider>().selectedRestaurant;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Restaurant is closed for pre-orders',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppTheme.errorRed,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Hours: ${r?.openingTime ?? '?'} - ${r?.closingTime ?? '?'}',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isASAP = _selectedTime == 'ASAP';
    final hasTimed = _selectedTime.isNotEmpty && !isASAP;

    return _buildSection(
      icon: Icons.schedule_rounded,
      title: 'Pickup Time',
      child: GestureDetector(
        onTap: () => _showTimeSlotPicker(timeSlots),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: isASAP
                ? const Color(0xFFFFF7ED)
                : hasTimed
                    ? AppTheme.emerald50
                    : AppTheme.backgroundLight,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(
              color: isASAP
                  ? const Color(0xFFF97316)
                  : hasTimed
                      ? AppTheme.primaryGreen
                      : AppTheme.border.withValues(alpha: 0.5),
              width: (isASAP || hasTimed) ? 2 : 1,
            ),
            boxShadow: AppTheme.shadowCard,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isASAP
                      ? const Color(0xFFFEF3C7)
                      : hasTimed
                          ? AppTheme.emerald50
                          : AppTheme.backgroundLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isASAP
                      ? Icons.bolt_rounded
                      : hasTimed
                          ? Icons.access_time_rounded
                          : Icons.schedule_outlined,
                  color: isASAP
                      ? const Color(0xFFF97316)
                      : hasTimed
                          ? AppTheme.primaryGreen
                          : AppTheme.textMuted,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedTime.isEmpty ? 'Select Pickup Time' : 'Pickup Time',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _selectedTime.isEmpty
                            ? AppTheme.textMuted
                            : AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedTime.isEmpty
                          ? 'Tap to choose when to arrive'
                          : isASAP
                              ? 'ASAP (+₹1 fee)'
                              : _selectedTime,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _selectedTime.isEmpty
                            ? AppTheme.textHint
                            : isASAP
                                ? const Color(0xFFF97316)
                                : AppTheme.primaryGreenDark,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isASAP
                      ? const Color(0xFFFEF3C7)
                      : AppTheme.emerald50,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isASAP
                        ? const Color(0xFFF97316).withValues(alpha: 0.4)
                        : AppTheme.primaryGreenLight,
                  ),
                ),
                child: Text(
                  _selectedTime.isEmpty ? 'Choose' : 'Change',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isASAP ? const Color(0xFFF97316) : AppTheme.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Bill Summary ───
  Widget _buildBillSummary({
    required CartProvider cart,
    required double subtotal,
    required double asapFee,
    required double couponDiscount,
    required double pointsDiscount,
    required double grandTotal,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(AppTheme.radius2XL),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bill Summary',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          // Item rows
          ...cart.items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppTheme.emerald50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${item.quantity}x',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.name,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '₹${item.subtotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),
          // Dashed divider
          LayoutBuilder(
            builder: (context, constraints) {
              const dashWidth = 4.0;
              final dashCount =
                  (constraints.constrainWidth() / (2 * dashWidth)).floor();
              return Flex(
                direction: Axis.horizontal,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(dashCount, (_) {
                  return SizedBox(
                    width: dashWidth,
                    height: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: AppTheme.divider),
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 12),

          _buildSummaryRow('Subtotal', '₹${subtotal.toStringAsFixed(0)}'),

          // Platform fee
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Platform Fee',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'FREE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '₹10',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textHint,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '₹0',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ASAP fee
          if (asapFee > 0) ...[
            const SizedBox(height: 4),
            _buildSummaryRow(
              'ASAP Fee',
              '+₹${asapFee.toStringAsFixed(0)}',
              color: const Color(0xFFF97316),
            ),
          ],

          // Coupon discount
          if (couponDiscount > 0) ...[
            const SizedBox(height: 4),
            _buildSummaryRow(
              'Coupon Discount',
              '- ₹${couponDiscount.toStringAsFixed(0)}',
              color: AppTheme.primaryGreen,
            ),
          ],

          // Points
          if (_usePoints && pointsDiscount > 0) ...[
            const SizedBox(height: 4),
            _buildSummaryRow(
              'Points (${(pointsDiscount * 10).toStringAsFixed(0)} pts)',
              '- ₹${pointsDiscount.toStringAsFixed(0)}',
              color: Colors.amber.shade700,
            ),
          ],

          // Grand Total
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.divider)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Grand Total',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  '₹${grandTotal.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Food Fact Card ───
  Widget _buildFoodFactCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(AppTheme.radius2XL),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              size: 20,
              color: Color(0xFFD97706),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Did you know?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentFact,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _currentFact = _foodFacts[Random().nextInt(_foodFacts.length)];
              });
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.backgroundLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.refresh_rounded, size: 16, color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    ).animate(delay: 200.ms).fadeIn(duration: 400.ms).slideY(begin: 0.05);
  }

  // ─── Suggestions Section ───
  Widget _buildSuggestionsSection(CartProvider cart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.auto_awesome, size: 16, color: AppTheme.primaryGreen),
            const SizedBox(width: 6),
            const Text(
              'You might also like',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              'from ${cart.restaurantName}',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(_suggestions.length, (index) {
          final item = _suggestions[index];
          final displayPrice =
              (item.sizes != null && item.sizes!.isNotEmpty)
                  ? item.sizes!.first.price
                  : item.price;

          return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWhite,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                  border: Border.all(color: AppTheme.border.withValues(alpha: 0.2)),
                  boxShadow: AppTheme.shadowSm,
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: item.imageUrl != null
                            ? Image.network(item.imageUrl!, fit: BoxFit.cover)
                            : Container(
                                color: AppTheme.emerald50,
                                child: const Center(
                                  child: Icon(
                                    Icons.restaurant_rounded,
                                    size: 20,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₹${displayPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _addSuggestion(item),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.emerald50,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: AppTheme.primaryGreenLight),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded, size: 16, color: AppTheme.primaryGreen),
                            SizedBox(width: 2),
                            Text(
                              'ADD',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
              .animate(delay: Duration(milliseconds: 80 * index))
              .fadeIn(duration: 300.ms)
              .slideX(begin: 0.05);
        }),
      ],
    ).animate(delay: 300.ms).fadeIn(duration: 400.ms);
  }

  // ─── Shared Section Wrapper ───
  Widget _buildSection({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(AppTheme.radius2XL),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primaryGreen),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 6),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color ?? AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color ?? AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
    required Color color,
  }) {
    final isSelected = _paymentMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.emerald50 : AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryGreen
                : AppTheme.border.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? AppTheme.shadowCard : null,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isSelected
                          ? AppTheme.primaryGreenDark
                          : AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppTheme.primaryGreen : AppTheme.textHint,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuantityButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}
