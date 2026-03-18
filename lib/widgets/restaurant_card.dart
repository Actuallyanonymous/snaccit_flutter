import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/theme.dart';
import '../models/restaurant.dart';

class RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onTap;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOwnerClosed = !restaurant.isOpen;
    final isTimeClosed = restaurant.isTimeClosed;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(AppTheme.radius3XL),
          border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
          boxShadow: AppTheme.shadowCard,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Image Section ───
            SizedBox(
              height: 180,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Restaurant image
                  restaurant.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: restaurant.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: AppTheme.divider,
                            child: const Center(
                              child: Icon(Icons.restaurant, color: AppTheme.textHint, size: 40),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: AppTheme.emerald50,
                            child: const Center(
                              child: Text('🍽️', style: TextStyle(fontSize: 48)),
                            ),
                          ),
                        )
                      : Container(
                          decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
                          child: const Center(
                            child: Text('🍽️', style: TextStyle(fontSize: 48)),
                          ),
                        ),

                  // Gradient overlay at bottom
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 60,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.3)],
                        ),
                      ),
                    ),
                  ),

                  // Owner-closed dark overlay
                  if (isOwnerClosed)
                    Container(
                      color: Colors.black.withValues(alpha: 0.55),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.errorRed,
                            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.errorRed.withValues(alpha: 0.4),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cancel, color: Colors.white, size: 18),
                              const SizedBox(width: 6),
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

                  // Time-closed subtle badge (no overlay — card still tappable)
                  if (!isOwnerClosed && isTimeClosed)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade600,
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                          boxShadow: AppTheme.shadowSm,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule, size: 13, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              restaurant.openingTime != null
                                  ? 'Opens at ${restaurant.openingTime}'
                                  : 'Closed Now',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Top-rated badge
                  if (!isOwnerClosed && !isTimeClosed && restaurant.rating != null && restaurant.rating! >= 4.5)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                          boxShadow: AppTheme.shadowSm,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 12, color: AppTheme.amber600),
                            const SizedBox(width: 3),
                            Text(
                              'Top Rated',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.amber600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // COD badge
                  if (!isOwnerClosed && restaurant.isCodAvailable)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                          boxShadow: AppTheme.shadowSm,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.payments_outlined, size: 12, color: AppTheme.primaryGreen),
                            const SizedBox(width: 3),
                            Text(
                              'COD',
                              style: TextStyle(
                                fontSize: 10,
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
                          restaurant.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (restaurant.rating != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreenLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, size: 12, color: AppTheme.primaryGreen),
                              const SizedBox(width: 2),
                              Text(
                                restaurant.rating!.toStringAsFixed(1),
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
                  if (restaurant.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      restaurant.description!,
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
                        // Time info
                        if (restaurant.openingTime != null)
                          Row(
                            children: [
                              Icon(Icons.schedule, size: 14, color: AppTheme.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                '${restaurant.openingTime} - ${restaurant.closingTime}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        const Spacer(),
                        // View menu CTA
                        if (!isOwnerClosed)
                          Row(
                            children: [
                              Text(
                                isTimeClosed ? 'Browse Menu' : 'View Menu',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isTimeClosed ? Colors.orange.shade700 : AppTheme.primaryGreen,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(Icons.arrow_forward, size: 14, 
                                color: isTimeClosed ? Colors.orange.shade700 : AppTheme.primaryGreen),
                            ],
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
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.04, duration: 400.ms)
     .then().shimmer(duration: 600.ms, color: AppTheme.primaryGreenLight.withValues(alpha: 0.15));
  }
}
