import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import '../config/theme.dart';
import 'profile_screen.dart';

class PaymentStatusScreen extends StatefulWidget {
  final String orderId;

  const PaymentStatusScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<PaymentStatusScreen> createState() => _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends State<PaymentStatusScreen> {
  String _orderStatus = 'awaiting_payment';
  String? _restaurantName;
  double? _total;
  StreamSubscription? _orderSubscription;
  bool _redirectTriggered = false;

  @override
  void initState() {
    super.initState();
    _listenToOrder();
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    super.dispose();
  }

  void _listenToOrder() {
    if (widget.orderId.isEmpty) {
      setState(() => _orderStatus = 'not_found');
      return;
    }

    _orderSubscription = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) {
        setState(() => _orderStatus = 'not_found');
        return;
      }

      final data = snapshot.data()!;
      setState(() {
        _orderStatus = data['status'] ?? 'awaiting_payment';
        _restaurantName = data['restaurantName'];
        _total = (data['total'] as num?)?.toDouble();
      });

      // On success statuses, auto-redirect to profile after delay
      final successStatuses = ['pending', 'accepted', 'preparing', 'ready', 'completed'];
      if (successStatuses.contains(_orderStatus) && !_redirectTriggered) {
        _redirectTriggered = true;
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
              (route) => route.isFirst,
            );
          }
        });
      }
    });
  }

  void _goToProfile() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
      (route) => route.isFirst,
    );
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goHome();
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: _buildContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_orderStatus) {
      case 'awaiting_payment':
        return _buildStatusCard(
          icon: Icons.hourglass_top,
          iconColor: Colors.blue,
          title: 'Processing Payment',
          subtitle: 'Please wait while we confirm your payment...',
          showSpinner: true,
        );

      case 'payment_failed':
      case 'payment_init_failed':
        return _buildStatusCard(
          icon: Icons.cancel,
          iconColor: AppTheme.errorRed,
          title: 'Payment Failed',
          subtitle: 'Your payment could not be processed. Please try again.',
          showButton: true,
          buttonText: 'Go to Home',
          onButtonPressed: _goHome,
        );

      case 'not_found':
        return _buildStatusCard(
          icon: Icons.help_outline,
          iconColor: Colors.orange,
          title: 'Order Not Found',
          subtitle: 'We couldn\'t find this order. Check your order history.',
          showButton: true,
          buttonText: 'Go to Profile',
          onButtonPressed: _goToProfile,
        );

      default:
        // Success states: pending, accepted, preparing, ready, completed
        return _buildStatusCard(
          icon: Icons.check_circle,
          iconColor: AppTheme.successGreen,
          title: 'Order Placed! 🎉',
          subtitle: _restaurantName != null
              ? 'Your order at $_restaurantName has been placed successfully!'
              : 'Your order has been placed successfully!',
          showTotal: true,
          showButton: true,
          buttonText: 'View My Orders',
          onButtonPressed: _goToProfile,
          autoRedirectHint: 'Redirecting to your orders...',
        );
    }
  }

  Widget _buildStatusCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    bool showSpinner = false,
    bool showTotal = false,
    bool showButton = false,
    String? buttonText,
    VoidCallback? onButtonPressed,
    String? autoRedirectHint,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: showSpinner
              ? Padding(
                  padding: const EdgeInsets.all(30),
                  child: CircularProgressIndicator(
                    color: iconColor,
                    strokeWidth: 3,
                  ),
                )
              : Icon(icon, size: 56, color: iconColor),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOut),

        const SizedBox(height: 28),

        // Title
        Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
          textAlign: TextAlign.center,
        ).animate(delay: 100.ms).fadeIn(duration: 300.ms),

        const SizedBox(height: 12),

        // Subtitle
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 15,
            color: AppTheme.textMuted,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ).animate(delay: 200.ms).fadeIn(duration: 300.ms),

        // Total
        if (showTotal && _total != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.emerald50,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: AppTheme.primaryGreenLight),
            ),
            child: Text(
              '₹${_total!.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppTheme.primaryGreen,
              ),
            ),
          ).animate(delay: 300.ms).fadeIn(duration: 300.ms),
        ],

        // Button
        if (showButton && buttonText != null) ...[
          const SizedBox(height: 32),
          GestureDetector(
            onTap: onButtonPressed,
            child: Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                gradient: AppTheme.buttonGradient,
                borderRadius: BorderRadius.circular(100),
                boxShadow: AppTheme.shadowGreen,
              ),
              alignment: Alignment.center,
              child: Text(
                buttonText,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ).animate(delay: 400.ms).fadeIn(duration: 300.ms),
        ],

        // Auto redirect hint
        if (autoRedirectHint != null) ...[
          const SizedBox(height: 16),
          Text(
            autoRedirectHint,
            style: TextStyle(fontSize: 12, color: AppTheme.textHint),
          ).animate(delay: 500.ms).fadeIn(duration: 300.ms),
        ],
      ],
    );
  }
}
