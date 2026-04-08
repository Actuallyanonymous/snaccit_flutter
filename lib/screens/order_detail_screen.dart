import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/theme.dart';
import '../models/order.dart';

class OrderDetailScreen extends StatelessWidget {
  final Order order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final statusInfo = _statusInfo(order.status);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ─── Hero Header ───
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: statusInfo.color,
            foregroundColor: Colors.white,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      statusInfo.color,
                      statusInfo.color.withValues(alpha: 0.85),
                      statusInfo.color.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    // Ambient circles for depth
                    Positioned(
                      top: -60,
                      right: -60,
                      child: Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.07),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -50,
                      left: -40,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 40,
                      right: 30,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.04),
                        ),
                      ),
                    ),
                    // Content
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 50, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Restaurant name
                            Text(
                              order.restaurantName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 24,
                                height: 1.2,
                                shadows: [
                                  Shadow(color: Colors.black26, blurRadius: 10),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Status + Payment pill row
                            Row(
                              children: [
                                // Status pill
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.15,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        statusInfo.icon,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        order.statusDisplay,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Payment pill
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.15,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        order.isCod
                                            ? Icons.payments_outlined
                                            : Icons.phone_android_rounded,
                                        size: 13,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        order.paymentDisplay,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Body Content ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Order Info Row ───
                  _GlassCard(
                    child: Row(
                      children: [
                        // Order ID
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ORDER ID',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textMuted,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    '#${order.id.substring(0, order.id.length > 8 ? 8 : order.id.length).toUpperCase()}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textPrimary,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      Clipboard.setData(
                                        ClipboardData(text: order.id),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: const Text(
                                            'Order ID copied!',
                                          ),
                                          backgroundColor:
                                              AppTheme.primaryGreen,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              100,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.emerald50,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.copy_rounded,
                                        size: 14,
                                        color: AppTheme.primaryGreen,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Date
                        if (order.createdAt != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'PLACED ON',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textMuted,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(order.createdAt!),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                _formatTime(order.createdAt!),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.03),

                  const SizedBox(height: 16),

                  // ─── Items ───
                  _SectionTitle(
                    title: 'Order Items',
                    icon: Icons.shopping_cart_outlined,
                  ),
                  const SizedBox(height: 10),
                  _GlassCard(
                        child: Column(
                          children: List.generate(order.items.length, (i) {
                            final item = order.items[i];
                            final isLast = i == order.items.length - 1;
                            return Container(
                              padding: EdgeInsets.only(
                                top: i == 0 ? 0 : 14,
                                bottom: isLast ? 0 : 14,
                              ),
                              decoration: BoxDecoration(
                                border: isLast
                                    ? null
                                    : Border(
                                        bottom: BorderSide(
                                          color: AppTheme.divider.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                      ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Quantity badge
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.primaryGradient,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${item.quantity}×',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        if (_hasCustomizations(item))
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                if (item.size != null &&
                                                    item.size!.isNotEmpty)
                                                  _CustomChip(
                                                    label: item.size!,
                                                  ),
                                                if (item.addons != null)
                                                  ...item.addons!.map(
                                                    (a) =>
                                                        _CustomChip(label: a),
                                                  ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '₹${(item.price * item.quantity).toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      )
                      .animate(delay: 100.ms)
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.03),

                  const SizedBox(height: 16),

                  // ─── Payment Summary ───
                  _SectionTitle(
                    title: 'Payment Summary',
                    icon: Icons.payments_outlined,
                  ),
                  const SizedBox(height: 10),
                  _GlassCard(
                        child: Column(
                          children: [
                            _SummaryRow(
                              label: 'Subtotal',
                              value: '₹${order.subtotal.toStringAsFixed(0)}',
                            ),
                            if (order.discount > 0)
                              _SummaryRow(
                                label:
                                    'Discount${order.couponCode != null ? ' (${order.couponCode})' : ''}',
                                value: '-₹${order.discount.toStringAsFixed(0)}',
                                valueColor: AppTheme.successGreen,
                              ),
                            if (order.pointsRedeemed > 0)
                              _SummaryRow(
                                label: 'Points (${order.pointsRedeemed} pts)',
                                value:
                                    '-₹${order.pointsValue.toStringAsFixed(0)}',
                                valueColor: AppTheme.successGreen,
                              ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.only(top: 14),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: AppTheme.primaryGreen.withValues(
                                      alpha: 0.2,
                                    ),
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Text(
                                    'Total Paid',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.primaryGradient,
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Text(
                                      '₹${order.total.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                      .animate(delay: 200.ms)
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.03),

                  const SizedBox(height: 16),

                  // ─── Details ───
                  _SectionTitle(
                    title: 'Details',
                    icon: Icons.info_outline_rounded,
                  ),
                  const SizedBox(height: 10),
                  _GlassCard(
                        child: Column(
                          children: [
                            _DetailRow(
                              icon: Icons.payments_outlined,
                              label: 'Payment Method',
                              value: order.paymentDisplay,
                              valueWidget: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: order.isCod
                                      ? const Color(0xFFFEF3C7)
                                      : const Color(0xFFE0E7FF),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  order.paymentDisplay,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: order.isCod
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFF4F46E5),
                                  ),
                                ),
                              ),
                            ),
                            if (order.arrivalTime != null) ...[
                              _divider(),
                              _DetailRow(
                                icon: Icons.schedule_rounded,
                                label: 'Arrival Time',
                                value: order.arrivalTime!,
                              ),
                            ],
                            if (order.createdAt != null) ...[
                              _divider(),
                              _DetailRow(
                                icon: Icons.calendar_today_rounded,
                                label: 'Order Date',
                                value: _formatFullDate(order.createdAt!),
                              ),
                            ],
                            if (order.orderNote != null &&
                                order.orderNote!.isNotEmpty) ...[
                              _divider(),
                              _DetailRow(
                                icon: Icons.sticky_note_2_outlined,
                                label: 'Note',
                                value: order.orderNote!,
                              ),
                            ],
                          ],
                        ),
                      )
                      .animate(delay: 300.ms)
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.03),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Divider(color: AppTheme.divider.withValues(alpha: 0.4), height: 1),
  );

  bool _hasCustomizations(OrderItem item) =>
      (item.size != null && item.size!.isNotEmpty) ||
      (item.addons != null && item.addons!.isNotEmpty);

  _StatusInfo _statusInfo(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
        return _StatusInfo(AppTheme.successGreen, Icons.check_circle_rounded);
      case OrderStatus.declined:
      case OrderStatus.failed:
      case OrderStatus.paymentFailed:
      case OrderStatus.paymentInitFailed:
        return _StatusInfo(AppTheme.errorRed, Icons.cancel_rounded);
      case OrderStatus.preparing:
        return _StatusInfo(const Color(0xFF4F46E5), Icons.restaurant_rounded);
      case OrderStatus.ready:
        return _StatusInfo(
          AppTheme.accentOrange,
          Icons.notifications_active_rounded,
        );
      case OrderStatus.accepted:
        return _StatusInfo(const Color(0xFF2563EB), Icons.thumb_up_rounded);
      case OrderStatus.awaitingPayment:
        return _StatusInfo(
          const Color(0xFF2563EB),
          Icons.hourglass_top_rounded,
        );
      case OrderStatus.pending:
        return _StatusInfo(
          const Color(0xFF059669),
          Icons.hourglass_top_rounded,
        );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    }
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${date.minute.toString().padLeft(2, '0')} $amPm';
  }

  String _formatFullDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.day} ${months[date.month - 1]} ${date.year}, $hour:${date.minute.toString().padLeft(2, '0')} $amPm';
  }
}

class _StatusInfo {
  final Color color;
  final IconData icon;
  const _StatusInfo(this.color, this.icon);
}

// ─── Glass Card ───
class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B7E6A).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── Section Title ───
class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryGreen),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ─── Summary Row ───
class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Detail Row ───
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? valueWidget;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.emerald50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppTheme.primaryGreen),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          valueWidget ??
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
        ],
      ),
    );
  }
}

// ─── Customization Chip ───
class _CustomChip extends StatelessWidget {
  final String label;
  const _CustomChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.emerald50,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: AppTheme.primaryGreenLight.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryGreen,
        ),
      ),
    );
  }
}
