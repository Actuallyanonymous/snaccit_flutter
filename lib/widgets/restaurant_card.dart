import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/theme.dart';
import '../models/restaurant.dart';

class RestaurantCard extends StatefulWidget {
  final Restaurant restaurant;
  final VoidCallback onTap;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    required this.onTap,
  });

  @override
  State<RestaurantCard> createState() => _RestaurantCardState();
}

class _RestaurantCardState extends State<RestaurantCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isOwnerClosed = !widget.restaurant.isOpen;
    final isTimeClosed = widget.restaurant.isTimeClosed;
    final isFullyOpen =
        widget.restaurant.isOpen && widget.restaurant.isCurrentlyInHours;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(AppTheme.radius2XL),
            border: Border.all(
              color: _isPressed
                  ? AppTheme.primaryGreen.withValues(alpha: 0.2)
                  : AppTheme.border.withValues(alpha: 0.3),
            ),
            boxShadow: _isPressed ? AppTheme.shadowMd : AppTheme.shadowCard,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Image Section ───
              SizedBox(
                height: 170,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Restaurant image
                    widget.restaurant.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: widget.restaurant.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: AppTheme.divider,
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: AppTheme.primaryGreen.withValues(
                                      alpha: 0.3,
                                    ),
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: AppTheme.emerald50,
                              child: const Center(
                                child: Icon(
                                  Icons.restaurant_rounded,
                                  size: 48,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            decoration: const BoxDecoration(
                              gradient: AppTheme.heroGradient,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.restaurant_rounded,
                                size: 48,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ),

                    // Gradient overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 70,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.6),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Owner-closed overlay
                    if (isOwnerClosed)
                      Container(
                        color: Colors.black.withValues(alpha: 0.55),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.errorRed,
                              borderRadius: BorderRadius.circular(100),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.errorRed.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.cancel_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Currently Closed',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Badges row (top)
                    if (!isOwnerClosed)
                      Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: Row(
                          children: [
                            // Time-closed badge
                            if (isTimeClosed)
                              _GlassBadge(
                                icon: Icons.schedule_rounded,
                                text: widget.restaurant.openingTime != null
                                    ? 'Opens ${widget.restaurant.openingTime}'
                                    : 'Closed Now',
                                color: Colors.orange.shade400,
                              ),

                            // Live open indicator
                            if (isFullyOpen)
                              _GlassBadge(
                                icon: null,
                                text: 'OPEN',
                                color: AppTheme.successGreen,
                                showDot: true,
                              ),

                            const Spacer(),

                            // COD badge
                            if (widget.restaurant.isCodAvailable)
                              _GlassBadge(
                                icon: Icons.payments_outlined,
                                text: 'COD',
                                color: Colors.white,
                              ),

                            // Top rated badge
                            if (widget.restaurant.rating != null &&
                                widget.restaurant.rating! >= 4.5) ...[
                              if (widget.restaurant.isCodAvailable)
                                const SizedBox(width: 6),
                              _GlassBadge(
                                icon: Icons.star_rounded,
                                text: 'Top Rated',
                                color: AppTheme.accentYellow,
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // ─── Content Section ───
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + Rating
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.restaurant.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.restaurant.rating != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryGreen.withValues(alpha: 0.1),
                                  AppTheme.emerald400.withValues(alpha: 0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.primaryGreen.withValues(
                                  alpha: 0.15,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 13,
                                  color: AppTheme.primaryGreen,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  widget.restaurant.rating!.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryGreenDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Description
                    if (widget.restaurant.description != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        widget.restaurant.description!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Footer
                    Container(
                      padding: const EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppTheme.divider),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (widget.restaurant.openingTime != null)
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 14,
                                  color: AppTheme.textMuted,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${widget.restaurant.openingTime} – ${widget.restaurant.closingTime}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          const Spacer(),
                          if (!isOwnerClosed)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isTimeClosed
                                    ? Colors.orange.shade50
                                    : AppTheme.emerald50,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: isTimeClosed
                                      ? Colors.orange.shade200
                                      : AppTheme.primaryGreenLight,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isTimeClosed ? 'Browse Menu' : 'View Menu',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isTimeClosed
                                          ? Colors.orange.shade700
                                          : AppTheme.primaryGreen,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 13,
                                    color: isTimeClosed
                                        ? Colors.orange.shade700
                                        : AppTheme.primaryGreen,
                                  ),
                                ],
                              ),
                            )
                          else
                            Text(
                              'Closed',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.errorRed,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.04, duration: 400.ms);
  }
}

// ─── Frosted Glass Badge ───
class _GlassBadge extends StatelessWidget {
  final IconData? icon;
  final String text;
  final Color color;
  final bool showDot;

  const _GlassBadge({
    this.icon,
    required this.text,
    required this.color,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showDot)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              if (icon != null) ...[
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
              ],
              Text(
                text,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
