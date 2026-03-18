import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:phonepe_payment_sdk/phonepe_payment_sdk.dart';
import '../config/theme.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../providers/restaurant_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'payment_status_screen.dart';
import 'payment_webview_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _selectedTime = 'ASAP';
  String _paymentMethod = 'phonepe';
  final _noteController = TextEditingController();
  final _couponController = TextEditingController();
  bool _usePoints = false;
  bool _isPlacingOrder = false;

  // Coupon state
  double _couponDiscount = 0;
  String? _couponError;
  Map<String, dynamic>? _appliedCoupon;
  bool _isValidatingCoupon = false;

  @override
  void dispose() {
    _noteController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  List<String> _generateTimeSlots() {
    final provider = context.read<RestaurantProvider>();
    final restaurant = provider.selectedRestaurant;

    if (restaurant?.openingTime == null || restaurant?.closingTime == null) {
      return [];
    }

    final now = DateTime.now();
    final openParts = restaurant!.openingTime!.split(':');
    final closeParts = restaurant.closingTime!.split(':');

    final openingTime = DateTime(now.year, now.month, now.day,
        int.parse(openParts[0]), int.parse(openParts[1]));
    final closingTime = DateTime(now.year, now.month, now.day,
        int.parse(closeParts[0]), int.parse(closeParts[1]));

    if (now.isAfter(closingTime) || now.isAtSameMomentAs(closingTime)) {
      return [];
    }

    final slots = <String>['ASAP'];
    const intervalMinutes = 5;
    const minimumLeadTimeMinutes = 15;

    var startTime = now.add(const Duration(minutes: minimumLeadTimeMinutes));
    final remainder = startTime.minute % intervalMinutes;
    if (remainder != 0) {
      startTime = DateTime(startTime.year, startTime.month, startTime.day,
          startTime.hour, startTime.minute + (intervalMinutes - remainder));
    }

    if (startTime.isBefore(openingTime)) {
      startTime = openingTime;
    }

    while (startTime.isBefore(closingTime)) {
      slots.add(DateFormat('h:mm a').format(startTime));
      startTime = startTime.add(const Duration(minutes: intervalMinutes));
    }

    return slots;
  }

  // ─── Coupon Validation (matches web app logic) ───
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

      // Validation checks
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
        setState(() => _couponError = 'Minimum order of ₹${minOrder.toStringAsFixed(0)} required.');
        return;
      }

      // Usage limit check
      if (coupon['usageLimit'] == 'once' && auth.firebaseUser != null) {
        final previousOrders = await FirebaseFirestore.instance
            .collection('orders')
            .where('userId', isEqualTo: auth.firebaseUser!.uid)
            .where('couponCode', isEqualTo: code)
            .where('status', whereIn: ['pending', 'accepted', 'preparing', 'ready', 'completed'])
            .limit(1)
            .get();

        if (previousOrders.docs.isNotEmpty) {
          setState(() => _couponError = 'You have already used this coupon.');
          return;
        }
      }

      // Calculate discount
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

  // ─── Points discount calculation ───
  double get _pointsDiscountValue {
    if (!_usePoints) return 0;
    final auth = context.read<AuthProvider>();
    final points = auth.userProfile?.points ?? 0;
    if (points <= 0) return 0;

    final cart = context.read<CartProvider>();
    final potentialDiscount = (points / 10).floorToDouble();
    final remainingToPay = (cart.subtotal - _couponDiscount).clamp(0.0, double.infinity);
    return potentialDiscount.clamp(0.0, remainingToPay).toDouble();
  }

  double get _grandTotal {
    final cart = context.read<CartProvider>();
    return (cart.subtotal - _couponDiscount - _pointsDiscountValue).clamp(0.0, double.infinity).toDouble();
  }

  Future<void> _placeOrder() async {
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
        couponCode: _appliedCoupon != null ? _appliedCoupon!['code'] as String : null,
        orderNote: _noteController.text.isNotEmpty ? _noteController.text : null,
      );

      final redirectUrl = result['redirectUrl'] as String?;
      final orderId = result['orderId'] as String?;
      // Capture grand total BEFORE clearing cart — _grandTotal reads from cart.subtotal
      final capturedGrandTotal = _grandTotal;
      debugPrint('🔗 Payment redirectUrl: $redirectUrl');
      debugPrint('💳 Payment method: $_paymentMethod');
      debugPrint('📦 Order ID: $orderId');
      debugPrint('💰 Grand total (captured): $capturedGrandTotal');

      // Reset state BEFORE navigating away
      if (mounted) setState(() => _isPlacingOrder = false);

      cart.clear();

      if (mounted) {
        if (_paymentMethod == 'cod' || capturedGrandTotal == 0) {
          // COD or fully points-paid — go straight to status screen
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => PaymentStatusScreen(
                orderId: orderId ?? _extractOrderId(redirectUrl),
              ),
            ),
            (route) => route.isFirst,
          );
        } else if (redirectUrl != null && redirectUrl.isNotEmpty) {
          // Route through snaccit.com to establish the HTTP Referer header.
          // PhonePe blocks payments when Referer is missing (which happens
          // when Chrome opens a URL from an external app in a new tab).
          final payRedirectUrl = 'https://www.snaccit.com/pay-redirect.html?url=${Uri.encodeComponent(redirectUrl)}';
          debugPrint('🌐 Opening payment via Referer redirect: $payRedirectUrl');
          
          final uri = Uri.parse(payRedirectUrl);
          try {
            await launchUrl(
              uri,
              mode: LaunchMode.inAppBrowserView, // Chrome Custom Tab — fast overlay, no full Chrome launch
            );
          } catch (e) {
            debugPrint('Could not launch external browser: $e');
          }
          
          // Immediately navigate to PaymentStatusScreen. We will rely on the 
          // backend webhook (PhonePe S2S callback) to update Firestore, 
          // which the Status Screen listens to.
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
          // Fallback
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
      debugPrint('🔴 FirebaseFunctionsException: code=${e.code}, message=${e.message}, details=${e.details}');
      if (mounted) {
        setState(() => _isPlacingOrder = false);
        // e.details contains the user-friendly message from the cloud function
        // e.message just returns the generic code like 'INTERNAL'
        final errorMsg = (e.details as String?) ?? e.message ?? 'Something went wrong. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(errorMsg)),
              ],
            ),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('🔴 Order error: $e');
      if (mounted) {
        setState(() => _isPlacingOrder = false);
        String errorMsg = 'Something went wrong. Please try again.';
        final eStr = e.toString();
        // Try to extract clean message from Firebase errors
        final bracketMatch = RegExp(r'\] (.+)$').firstMatch(eStr);
        if (bracketMatch != null) {
          errorMsg = bracketMatch.group(1)!;
        } else if (eStr.contains('Exception: ')) {
          errorMsg = eStr.replaceAll('Exception: ', '');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(errorMsg)),
              ],
            ),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  String _extractOrderId(String? url) {
    if (url == null) return '';
    final uri = Uri.tryParse(url);
    return uri?.queryParameters['orderId'] ?? '';
  }

  void _showTimeSlotPicker(List<String> timeSlots) {
    String tempSelected = timeSlots.contains(_selectedTime) ? _selectedTime : timeSlots.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          decoration: BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
                    const Icon(Icons.access_time_rounded, color: AppTheme.primaryGreen, size: 22),
                    const SizedBox(width: 10),
                    const Text(
                      'Select Pickup Time',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Slots grid
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: timeSlots.map((slot) {
                      final isSelected = tempSelected == slot;
                      return GestureDetector(
                        onTap: () => setModalState(() => tempSelected = slot),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primaryGreen : AppTheme.surfaceWhite,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryGreen : AppTheme.border.withValues(alpha: 0.5),
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected ? AppTheme.shadowGreen : AppTheme.shadowCard,
                          ),
                          child: Text(
                            slot,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              // Confirm button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: SafeArea(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedTime = tempSelected);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: AppTheme.buttonGradient,
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: AppTheme.shadowGreen,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Confirm · $tempSelected',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
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

  String _getDiscountSummary(AuthProvider auth) {
    final parts = <String>[];
    if (_appliedCoupon != null) {
      parts.add('Coupon "${_appliedCoupon!['code']}" (-₹${_couponDiscount.toStringAsFixed(0)})');
    }
    if (_usePoints && _pointsDiscountValue > 0) {
      parts.add('Points (-₹${_pointsDiscountValue.toStringAsFixed(0)})');
    }
    if (parts.isEmpty) {
      final hasPoints = auth.userProfile != null && (auth.userProfile!.points) > 0;
      return hasPoints ? 'Apply coupon or use points' : 'Apply a coupon code';
    }
    return parts.join(' · ');
  }

  void _showDiscountsModal(AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
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
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.local_offer_rounded, color: AppTheme.primaryGreen, size: 22),
                      const SizedBox(width: 10),
                      const Text(
                        'Discounts & Offers',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ─── Coupon Section ───
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Coupon Code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary)),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundLight,
                          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                          border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _couponController,
                                textCapitalization: TextCapitalization.characters,
                                enabled: _appliedCoupon == null,
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
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        shape: const StadiumBorder(),
                                      ),
                                      child: const Text('Remove', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                    )
                                  : TextButton(
                                      onPressed: (_isValidatingCoupon || _couponController.text.trim().isEmpty)
                                          ? null
                                          : () async {
                                              await _applyCoupon();
                                              setModalState(() {});
                                            },
                                      style: TextButton.styleFrom(
                                        backgroundColor: AppTheme.primaryGreen,
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.4),
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                        shape: const StadiumBorder(),
                                      ),
                                      child: _isValidatingCoupon
                                          ? const SizedBox(
                                              width: 16, height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : const Text('Apply', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
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
                            style: TextStyle(color: AppTheme.errorRed, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      if (_appliedCoupon != null && _couponError == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, size: 14, color: AppTheme.primaryGreen),
                              const SizedBox(width: 4),
                              Text(
                                'Coupon "${_appliedCoupon!['code']}" applied! (-₹${_couponDiscount.toStringAsFixed(0)})',
                                style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // ─── Points Section ───
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
                          color: _usePoints ? AppTheme.emerald50 : AppTheme.backgroundLight,
                          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                          border: Border.all(
                            color: _usePoints ? AppTheme.primaryGreen : AppTheme.border.withValues(alpha: 0.5),
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
                                  color: _usePoints ? AppTheme.primaryGreen : AppTheme.textHint,
                                  width: 2,
                                ),
                                color: _usePoints ? AppTheme.primaryGreen : Colors.transparent,
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
                                      color: _usePoints ? AppTheme.primaryGreenDark : AppTheme.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Save ₹${(auth.userProfile!.points / 10).toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _usePoints ? AppTheme.primaryGreen : AppTheme.textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Text('🎁', style: TextStyle(fontSize: 22)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],

                // Done button
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
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
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

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final auth = context.watch<AuthProvider>();
    final timeSlots = _generateTimeSlots();
    final subtotal = cart.subtotal;
    final pointsDiscount = _pointsDiscountValue;
    final grandTotal = _grandTotal;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWhite,
        title: const Text('Checkout'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Arrival Time ───
            _buildSection(
              icon: Icons.schedule,
              title: 'Estimated Arrival Time',
              child: timeSlots.isEmpty
                  ? Container(
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Restaurant is closed for pre-orders',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.errorRed),
                                ),
                                const SizedBox(height: 2),
                                Builder(builder: (_) {
                                  final r = context.read<RestaurantProvider>().selectedRestaurant;
                                  return Text(
                                    'Hours: ${r?.openingTime ?? '?'} - ${r?.closingTime ?? '?'}',
                                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : GestureDetector(
                      onTap: () => _showTimeSlotPicker(timeSlots),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceWhite,
                          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                          border: Border.all(color: AppTheme.border.withValues(alpha: 0.4)),
                          boxShadow: AppTheme.shadowCard,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.emerald50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.access_time_rounded, color: AppTheme.primaryGreen, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pickup Time',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    timeSlots.contains(_selectedTime) ? _selectedTime : timeSlots.first,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.emerald50,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(color: AppTheme.primaryGreenLight),
                              ),
                              child: const Text(
                                'Change',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ).animate().fadeIn(duration: 300.ms),

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
                    borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                  counterStyle: TextStyle(color: AppTheme.textHint, fontSize: 11),
                ),
              ),
            ).animate(delay: 50.ms).fadeIn(duration: 300.ms),

            const SizedBox(height: 14),

            // ─── Discounts & Offers (compact button → modal) ───
            GestureDetector(
              onTap: () => _showDiscountsModal(auth),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWhite,
                  borderRadius: BorderRadius.circular(AppTheme.radius2XL),
                  border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
                  boxShadow: AppTheme.shadowCard,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.emerald50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.local_offer_rounded, color: AppTheme.primaryGreen, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Discounts & Offers',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getDiscountSummary(auth),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: (_couponDiscount > 0 || (_usePoints && _pointsDiscountValue > 0))
                                  ? AppTheme.primaryGreen
                                  : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_couponDiscount > 0 || (_usePoints && _pointsDiscountValue > 0))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.emerald50,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: AppTheme.primaryGreenLight),
                        ),
                        child: Text(
                          '-₹${(_couponDiscount + _pointsDiscountValue).toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.primaryGreen),
                        ),
                      )
                    else
                      const Icon(Icons.chevron_right_rounded, color: AppTheme.textHint, size: 24),
                  ],
                ),
              ),
            ).animate(delay: 100.ms).fadeIn(duration: 300.ms),

            const SizedBox(height: 14),

            // ─── Order Summary ───
            _buildSection(
              icon: Icons.receipt_long,
              title: 'Order Summary',
              child: Column(
                children: [
                  // Item rows
                  ...cart.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: AppTheme.emerald50,
                            borderRadius: BorderRadius.circular(4),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary),
                              ),
                              if (item.selectedSize != null || item.selectedAddons.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    [if (item.selectedSize != null) item.selectedSize, ...item.selectedAddons].join(' · '),
                                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '₹${item.subtotal.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                  )),

                  // Divider
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: AppTheme.divider)),
                    ),
                    child: Column(
                      children: [
                        // Subtotal
                        _buildSummaryRow('Subtotal', '₹${subtotal.toStringAsFixed(0)}'),

                        // Platform Fee
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text('Platform Fee', style: TextStyle(fontSize: 13, color: AppTheme.primaryGreen, fontWeight: FontWeight.w600)),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppTheme.emerald50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('FREE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.primaryGreen)),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text('₹10', style: TextStyle(fontSize: 12, color: AppTheme.textHint, decoration: TextDecoration.lineThrough)),
                                const SizedBox(width: 4),
                                Text('₹0', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen)),
                              ],
                            ),
                          ],
                        ),

                        // Coupon Discount
                        if (_couponDiscount > 0) ...[
                          const SizedBox(height: 4),
                          _buildSummaryRow(
                            'Coupon Discount',
                            '- ₹${_couponDiscount.toStringAsFixed(0)}',
                            color: AppTheme.primaryGreen,
                          ),
                        ],

                        // Points Redeemed
                        if (_usePoints && pointsDiscount > 0) ...[
                          const SizedBox(height: 4),
                          _buildSummaryRow(
                            'Points (${(pointsDiscount * 10).toStringAsFixed(0)} pts)',
                            '- ₹${pointsDiscount.toStringAsFixed(0)}',
                            color: Colors.amber.shade700,
                          ),
                        ],

                        // Grand Total
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: AppTheme.divider)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Grand Total',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary),
                              ),
                              Text(
                                '₹${grandTotal.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate(delay: 150.ms).fadeIn(duration: 300.ms),

            const SizedBox(height: 14),

            // ─── Payment Method (after order summary) ───
            Builder(
              builder: (context) {
                final restaurant = context.read<RestaurantProvider>().selectedRestaurant;
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
            ).animate(delay: 200.ms).fadeIn(duration: 300.ms),
          ],
        ),
      ),

      // ─── Bottom Bar ───
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B7E6A).withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          child: GestureDetector(
            onTap: (_isPlacingOrder || timeSlots.isEmpty) ? null : _placeOrder,
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: (_isPlacingOrder || timeSlots.isEmpty) ? null : AppTheme.buttonGradient,
                color: (_isPlacingOrder || timeSlots.isEmpty) ? AppTheme.primaryGreen.withValues(alpha: 0.5) : null,
                borderRadius: BorderRadius.circular(100),
                boxShadow: (_isPlacingOrder || timeSlots.isEmpty) ? null : AppTheme.shadowGreen,
              ),
              alignment: Alignment.center,
              child: _isPlacingOrder
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shopping_bag_rounded, size: 20, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          grandTotal == 0
                              ? 'Confirm Order (₹0)'
                              : _paymentMethod == 'cod'
                                  ? 'Place Order · ₹${grandTotal.toStringAsFixed(0)} (COD)'
                                  : 'Place Order · ₹${grandTotal.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color ?? AppTheme.textSecondary)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color ?? AppTheme.textPrimary)),
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
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : AppTheme.border.withValues(alpha: 0.5),
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
                borderRadius: BorderRadius.circular(10),
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
                      color: isSelected ? AppTheme.primaryGreenDark : AppTheme.textPrimary,
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
}
