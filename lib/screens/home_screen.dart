import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/theme.dart';
import '../models/popular_dish.dart';
import '../models/restaurant.dart';
import '../providers/restaurant_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/restaurant_card.dart';
import '../widgets/cart_dock.dart';
import 'menu_screen.dart';
import 'auth_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _searchQuery = '';
  bool _isSearchFocused = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<RestaurantProvider>();
    if (provider.restaurants.isEmpty) {
      provider.listenToRestaurants();
    }
    _searchFocusNode.addListener(() {
      setState(() => _isSearchFocused = _searchFocusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onRestaurantTap(Restaurant restaurant) {
    HapticFeedback.lightImpact();

    if (!restaurant.isOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.cancel, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('This restaurant is currently closed'),
            ],
          ),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
        ),
      );
      return;
    }

    context.read<RestaurantProvider>().selectRestaurant(restaurant);
    context.read<CartProvider>().setRestaurant(restaurant.id, restaurant.name);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MenuScreen(restaurant: restaurant),
      ),
    );
  }

  void _goToProfile() {
    HapticFeedback.lightImpact();
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            // Main content
            SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ─── Hero Header ───
                  SliverToBoxAdapter(child: _buildHeroHeader()),

                  // ─── Popular Dishes Section ───
                  Consumer<RestaurantProvider>(
                    builder: (context, provider, _) {
                      if (provider.popularDishes.isEmpty ||
                          _searchQuery.isNotEmpty) {
                        return const SliverToBoxAdapter(
                          child: SizedBox.shrink(),
                        );
                      }

                      return SliverToBoxAdapter(
                        child: _buildPopularDishesSection(
                          provider.popularDishes,
                        ),
                      );
                    },
                  ),

                  // ─── Pre-Order Benefits Banner ───
                  if (_searchQuery.isEmpty)
                    SliverToBoxAdapter(child: _buildPreOrderBanner()),

                  // ─── Section Title ───
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 22,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'All Restaurants',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Consumer<RestaurantProvider>(
                            builder: (context, p, _) {
                              final count = p.restaurants
                                  .where((r) => r.isVisible)
                                  .length;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.emerald50,
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  '$count places',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
                  ),

                  // ─── Restaurant List ───
                  Consumer<RestaurantProvider>(
                    builder: (context, provider, _) {
                      if (provider.isLoading) {
                        return SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildShimmerCard(index),
                              childCount: 3,
                            ),
                          ),
                        );
                      }

                      var restaurants = provider.restaurants
                          .where((r) => r.isVisible)
                          .toList();

                      if (_searchQuery.isNotEmpty) {
                        restaurants = restaurants
                            .where(
                              (r) => r.name.toLowerCase().contains(
                                _searchQuery.toLowerCase(),
                              ),
                            )
                            .toList();
                      }

                      restaurants.sort((a, b) {
                        int priority(Restaurant r) {
                          if (r.isOpen && r.isCurrentlyInHours) return 0;
                          if (r.isTimeClosed) return 1;
                          return 2;
                        }

                        return priority(a).compareTo(priority(b));
                      });

                      if (restaurants.isEmpty) {
                        return SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: AppTheme.emerald50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.search_off_rounded,
                                      size: 36,
                                      color: AppTheme.primaryGreen,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No restaurants match "$_searchQuery"'
                                      : 'No restaurants available',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Try a different search',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(),
                        );
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final restaurant = restaurants[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: RestaurantCard(
                                restaurant: restaurant,
                                onTap: () => _onRestaurantTap(restaurant),
                              ),
                            );
                          }, childCount: restaurants.length),
                        ),
                      );
                    },
                  ),

                  // Bottom padding for cart dock
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            ),

            // ─── Cart Dock ───
            const CartDock(),
          ],
        ),
      ),
    );
  }

  // ─── Hero Header ───
  Widget _buildHeroHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting + Avatar row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Consumer<AuthProvider>(
                      builder: (context, auth, _) => Text(
                        auth.isLoggedIn
                            ? 'Hey, ${auth.userProfile?.name ?? 'there'}'
                            : 'Snaccit',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          height: 1.2,
                        ),
                      ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.03),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                          'Pre Order food and skip the wait',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryGreen,
                            letterSpacing: 0.3,
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 100.ms, duration: 400.ms)
                        .slideX(begin: -0.05),
                  ],
                ),
              ),

              // Profile avatar with gradient ring
              GestureDetector(
                    onTap: _goToProfile,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppTheme.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryGreen.withValues(
                              alpha: 0.25,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: AppTheme.surfaceWhite,
                          shape: BoxShape.circle,
                        ),
                        child: Consumer<AuthProvider>(
                          builder: (context, auth, _) => Center(
                            child: auth.isLoggedIn
                                ? (auth.userProfile == null
                                      ? Container(
                                              width: 44,
                                              height: 44,
                                              decoration: const BoxDecoration(
                                                color: AppTheme.surfaceWhite,
                                                shape: BoxShape.circle,
                                              ),
                                            )
                                            .animate(onPlay: (c) => c.repeat())
                                            .shimmer(
                                              color: AppTheme.primaryGreen
                                                  .withValues(alpha: 0.2),
                                              duration: 1.seconds,
                                            )
                                      : Text(
                                          (auth.userProfile?.name ?? 'U')[0]
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.primaryGreen,
                                          ),
                                        ))
                                : const Icon(
                                    Icons.person_outline_rounded,
                                    color: AppTheme.primaryGreen,
                                    size: 22,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 400.ms)
                  .scale(begin: const Offset(0.8, 0.8)),
            ],
          ),

          const SizedBox(height: 6),

          // Quick stats row for logged-in users
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              if (!auth.isLoggedIn) return const SizedBox(height: 14);
              return Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 6),
                    child: Row(
                      children: [
                        _buildStatPillWithIcon(
                          Icons.card_giftcard,
                          '${auth.userProfile?.points ?? 0} pts',
                          AppTheme.emerald50,
                          AppTheme.primaryGreen,
                        ),
                        const SizedBox(width: 8),
                        if (auth.userProfile?.referralCode != null)
                          _buildStatPillWithIcon(
                            Icons.share_rounded,
                            'Refer & Earn',
                            const Color(0xFFFEF3C7),
                            AppTheme.amber600,
                          ),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 400.ms)
                  .slideY(begin: 0.1);
            },
          ),

          const SizedBox(height: 16),

          // ─── Frosted Search Bar ───
          AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                clipBehavior: Clip.antiAlias,
                margin: EdgeInsets.symmetric(
                  horizontal: _isSearchFocused ? 0 : 6,
                ),
                decoration: BoxDecoration(
                  color: _isSearchFocused
                      ? AppTheme.surfaceWhite
                      : AppTheme.surfaceWhite.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: _isSearchFocused
                        ? AppTheme.primaryGreen.withValues(alpha: 0.5)
                        : AppTheme.border.withValues(alpha: 0.5),
                    width: _isSearchFocused ? 2 : 1,
                  ),
                  boxShadow: _isSearchFocused
                      ? AppTheme.shadowMd
                      : AppTheme.shadowSoft,
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    filled: false,
                    hintText: 'Search restaurants...',
                    hintStyle: TextStyle(
                      color: AppTheme.textHint,
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.search_rounded,
                        color: _isSearchFocused || _searchQuery.isNotEmpty
                            ? AppTheme.primaryGreen
                            : AppTheme.textHint,
                        size: 22,
                      ),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppTheme.border.withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                              _searchFocusNode.unfocus();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              )
              .animate()
              .fadeIn(delay: 200.ms, duration: 400.ms)
              .slideY(begin: 0.05),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ─── Popular Dishes Carousel ───
  void _quickAddDish(PopularDish dish) {
    HapticFeedback.mediumImpact();
    final cart = context.read<CartProvider>();

    if (!cart.canAddFrom(dish.restaurantId)) {
      // Show the "Start a new cart?" bottom sheet
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) => Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 32,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24, 20, 24, MediaQuery.of(ctx).padding.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                Container(
                  width: 64, height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.shopping_cart_outlined,
                      size: 28, color: Color(0xFFD97706),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Start a new cart?',
                  style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary, letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your cart has items from ${cart.restaurantName ?? 'another restaurant'}. Adding this item will clear your current cart.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14, color: AppTheme.textSecondary, height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed,
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.errorRed.withValues(alpha: 0.30),
                          blurRadius: 16, offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(100),
                        onTap: () {
                          Navigator.pop(ctx);
                          cart.clear(
                            newRestaurantId: dish.restaurantId,
                            newRestaurantName: dish.restaurantName,
                          );
                          cart.addItem(menuItem: dish.item);
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Clear cart & add item',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white, fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(100),
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundLight,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: AppTheme.border.withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Text(
                          'Keep current cart',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textPrimary, fontSize: 16,
                            fontWeight: FontWeight.w600,
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
      return;
    }

    // No conflict — set restaurant context and add
    cart.setRestaurant(dish.restaurantId, dish.restaurantName);
    cart.addItem(menuItem: dish.item);
  }

  Widget _buildPopularDishesSection(List<PopularDish> dishes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Row(
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                size: 20,
                color: AppTheme.accentOrange,
              ),
              const SizedBox(width: 6),
              const Text(
                'Popular Right Now',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'LIVE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.amber600,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: dishes.length,
            itemBuilder: (context, index) {
              final dish = dishes[index];
              final item = dish.item;
              final displayPrice =
                  (item.sizes != null && item.sizes!.isNotEmpty)
                  ? item.sizes!.first.price
                  : item.price;

              return Container(
                    width: 160,
                    margin: const EdgeInsets.only(right: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceWhite,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                      border: Border.all(
                        color: AppTheme.border.withValues(alpha: 0.2),
                      ),
                      boxShadow: AppTheme.shadowCard,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Dish image
                        SizedBox(
                          height: 90,
                          width: double.infinity,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              item.imageUrl != null
                                  ? Image.network(
                                      item.imageUrl!,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color: AppTheme.emerald50,
                                      child: const Center(
                                        child: Icon(
                                          Icons.restaurant_rounded,
                                          size: 28,
                                          color: AppTheme.primaryGreen,
                                        ),
                                      ),
                                    ),
                              // Quick-add button
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: GestureDetector(
                                  onTap: () => _quickAddDish(dish),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryGreen,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.primaryGreen
                                              .withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.add_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Details
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
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
                              const SizedBox(height: 3),
                              Text(
                                dish.restaurantName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${displayPrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                  .animate(delay: Duration(milliseconds: 80 * index))
                  .fadeIn(duration: 400.ms)
                  .slideX(begin: 0.08);
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    ).animate().fadeIn(delay: 250.ms, duration: 400.ms);
  }

  // ─── Shimmer Loading Card ───
  Widget _buildShimmerCard(int index) {
    return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(AppTheme.radius2XL),
            border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
            boxShadow: AppTheme.shadowCard,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image placeholder
              Container(
                height: 170, // matches RestaurantCard height
                color: AppTheme.divider,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 150,
                          height: 20,
                          decoration: BoxDecoration(
                            color: AppTheme.divider,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 40,
                          height: 20,
                          decoration: BoxDecoration(
                            color: AppTheme.divider,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 220,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppTheme.divider,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppTheme.divider),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 100,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppTheme.divider,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: 80,
                            height: 24,
                            decoration: BoxDecoration(
                              color: AppTheme.divider,
                              borderRadius: BorderRadius.circular(100),
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
        )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1500.ms, color: Colors.white.withValues(alpha: 0.6))
        .animate(delay: Duration(milliseconds: 100 * index))
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.04);
  }

  Widget _buildStatPillWithIcon(
    IconData icon,
    String text,
    Color bgColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: textColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  // _getGreeting removed — replaced with brand-first header

  // ─── Pre-Order Benefits Banner ───
  Widget _buildPreOrderBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: _PreOrderBannerCard(),
    ).animate().fadeIn(delay: 200.ms, duration: 500.ms).slideY(
          begin: 0.06,
          curve: Curves.easeOutCubic,
        );
  }
}

// ══════════════════════════════════════════════════════════════════
//  PRE-ORDER BANNER CARD
// ══════════════════════════════════════════════════════════════════
class _PreOrderBannerCard extends StatefulWidget {
  @override
  State<_PreOrderBannerCard> createState() => _PreOrderBannerCardState();
}

class _PreOrderBannerCardState extends State<_PreOrderBannerCard>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final AnimationController _shimmerCtrl;
  late final AnimationController _pulseCtrl;

  late final List<Animation<double>> _stepFadeAnims;
  late final List<Animation<double>> _stepScaleAnims;
  late final Animation<double> _shimmerAnim;
  late final Animation<double> _pulseAnim;

  bool _tapped = false;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _stepFadeAnims = List.generate(3, (i) {
      final start = 0.2 + i * 0.2;
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _entryCtrl,
          curve: Interval(start, (start + 0.35).clamp(0.0, 1.0),
              curve: Curves.easeOut),
        ),
      );
    });

    _stepScaleAnims = List.generate(3, (i) {
      final start = 0.2 + i * 0.2;
      return Tween<double>(begin: 0.72, end: 1.0).animate(
        CurvedAnimation(
          parent: _entryCtrl,
          curve: Interval(start, (start + 0.35).clamp(0.0, 1.0),
              curve: Curves.easeOutBack),
        ),
      );
    });

    _shimmerAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );

    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _entryCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _shimmerCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _openSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _TimeSavedSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _tapped = true),
      onTapUp: (_) {
        setState(() => _tapped = false);
        _openSheet();
      },
      onTapCancel: () => setState(() => _tapped = false),
      child: AnimatedScale(
        scale: _tapped ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: _buildCard(),
      ),
    );
  }

  Widget _buildCard() {
    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (context, child) {
        final shift = _shimmerAnim.value * 0.14;
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: const [
                Color(0xFF004D40),
                Color(0xFF00695C),
                Color(0xFF00897B),
                Color(0xFF26A69A),
              ],
              stops: const [0.0, 0.35, 0.70, 1.0],
              begin: Alignment(-1.0 + shift, -0.6 + shift * 0.5),
              end: Alignment(1.0 + shift * 0.3, 1.0),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF004D40).withValues(alpha: 0.45),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: const Color(0xFF26A69A).withValues(alpha: 0.20),
                blurRadius: 48,
                spreadRadius: -6,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: child,
        );
      },
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildLabelPill(),
              const Spacer(),
              _TapHintChip(onTap: _openSheet),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Order ahead.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Arrive to your food.',
            style: TextStyle(
              color: Color(0xFFB2DFDB),
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _PreOrderStep(
                icon: Icons.restaurant_menu_rounded,
                label: 'Place\nOrder',
                fadeAnim: _stepFadeAnims[0],
                scaleAnim: _stepScaleAnims[0],
                pulseAnim: null,
              ),
              _StepConnector(fadeAnim: _stepFadeAnims[0]),
              _PreOrderStep(
                icon: Icons.schedule_rounded,
                label: 'Food\nPrepared',
                fadeAnim: _stepFadeAnims[1],
                scaleAnim: _stepScaleAnims[1],
                pulseAnim: _pulseAnim,
              ),
              _StepConnector(fadeAnim: _stepFadeAnims[1]),
              _PreOrderStep(
                icon: Icons.directions_walk_rounded,
                label: 'Arrive\n& Go',
                fadeAnim: _stepFadeAnims[2],
                scaleAnim: _stepScaleAnims[2],
                pulseAnim: null,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _BottomTagline(onTap: _openSheet),
        ],
      ),
    );
  }

  Widget _buildLabelPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: const Text(
        'WHY PRE-ORDER?',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  STEP INDICATOR  — glassmorphic with optional pulsating glow
// ══════════════════════════════════════════════════════════════════
class _PreOrderStep extends StatelessWidget {
  const _PreOrderStep({
    required this.icon,
    required this.label,
    required this.fadeAnim,
    required this.scaleAnim,
    required this.pulseAnim,
  });

  final IconData icon;
  final String label;
  final Animation<double> fadeAnim;
  final Animation<double> scaleAnim;
  final Animation<double>? pulseAnim;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedBuilder(
        animation: Listenable.merge([fadeAnim, scaleAnim]),
        builder: (context, child) => Opacity(
          opacity: fadeAnim.value,
          child: Transform.scale(scale: scaleAnim.value, child: child),
        ),
        child: Column(
          children: [
            _buildIconContainer(),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconContainer() {
    final glassBox = ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.32),
              width: 1,
            ),
          ),
          child: Center(child: Icon(icon, color: Colors.white, size: 26)),
        ),
      ),
    );

    if (pulseAnim == null) return glassBox;

    return AnimatedBuilder(
      animation: pulseAnim!,
      builder: (context, child) {
        final spread = 2.0 + pulseAnim!.value * 10.0;
        final alpha = 0.20 + pulseAnim!.value * 0.25;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 62 + spread * 2,
              height: 62 + spread * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF80CBC4).withValues(alpha: alpha),
                    blurRadius: 20,
                    spreadRadius: spread * 0.5,
                  ),
                ],
              ),
            ),
            child!,
          ],
        );
      },
      child: glassBox,
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  STEP CONNECTOR
// ══════════════════════════════════════════════════════════════════
class _StepConnector extends StatelessWidget {
  const _StepConnector({required this.fadeAnim});
  final Animation<double> fadeAnim;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: fadeAnim,
      builder: (_, __) => Opacity(
        opacity: (fadeAnim.value * 2.0).clamp(0.0, 1.0),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 30, left: 2, right: 2),
          child: Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.white.withValues(alpha: 0.50),
            size: 13,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  TAP HINT CHIP
// ══════════════════════════════════════════════════════════════════
class _TapHintChip extends StatefulWidget {
  const _TapHintChip({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_TapHintChip> createState() => _TapHintChipState();
}

class _TapHintChipState extends State<_TapHintChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, child) => Opacity(opacity: _anim.value, child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
              width: 0.8,
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app_rounded, color: Colors.white, size: 13),
              SizedBox(width: 5),
              Text(
                'Tap to see',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  BOTTOM TAGLINE
// ══════════════════════════════════════════════════════════════════
class _BottomTagline extends StatefulWidget {
  const _BottomTagline({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_BottomTagline> createState() => _BottomTaglineState();
}

class _BottomTaglineState extends State<_BottomTagline> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 80),
        opacity: _pressed ? 0.55 : 1.0,
        child: Container(
          padding: const EdgeInsets.only(top: 14),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.bolt_rounded,
                  color: Color(0xFF80CBC4), size: 16),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'Walk in, grab your meal, skip the queue. Every time.',
                  style: TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withValues(alpha: 0.45), size: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  TIME SAVED BOTTOM SHEET
// ══════════════════════════════════════════════════════════════════
class _TimeSavedSheet extends StatefulWidget {
  const _TimeSavedSheet();

  @override
  State<_TimeSavedSheet> createState() => _TimeSavedSheetState();
}

class _TimeSavedSheetState extends State<_TimeSavedSheet>
    with TickerProviderStateMixin {
  late final AnimationController _ringCtrl;
  late final AnimationController _countCtrl;
  late final Animation<double> _ringAnim;
  late final Animation<int> _minutesAnim;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _ringAnim =
        CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOutCubic);

    _countCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _minutesAnim = IntTween(begin: 0, end: 15).animate(
      CurvedAnimation(parent: _countCtrl, curve: Curves.easeOutCubic),
    );

    Future.delayed(const Duration(milliseconds: 280), () {
      if (mounted) {
        _ringCtrl.forward();
        _countCtrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _countCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.13),
            blurRadius: 48,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          const SizedBox(height: 32),
          AnimatedBuilder(
            animation: _ringAnim,
            builder: (context, _) => SizedBox(
              width: 150,
              height: 150,
              child: CustomPaint(
                painter: _ClockArcPainter(progress: _ringAnim.value),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 34,
                        color: AppTheme.primaryGreen
                            .withValues(alpha: _ringAnim.value.clamp(0.0, 1.0)),
                      ),
                      const SizedBox(height: 4),
                      AnimatedBuilder(
                        animation: _minutesAnim,
                        builder: (_, __) => Text(
                          '${_minutesAnim.value} min',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary.withValues(
                                alpha: _ringAnim.value.clamp(0.0, 1.0)),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
              .animate()
              .fadeIn(delay: 150.ms, duration: 600.ms)
              .scale(
                begin: const Offset(0.72, 0.72),
                delay: 150.ms,
                duration: 900.ms,
                curve: Curves.elasticOut,
              ),
          const SizedBox(height: 22),
          const Text(
            'Average Time Saved',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.4,
            ),
          ).animate().fadeIn(delay: 380.ms, duration: 450.ms).slideY(begin: 0.1),
          const SizedBox(height: 5),
          Text(
            'by pre-ordering on Snaccit',
            style: TextStyle(fontSize: 13.5, color: AppTheme.textMuted),
          ).animate().fadeIn(delay: 460.ms, duration: 450.ms),
          const SizedBox(height: 28),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              children: [
                Row(children: [
                  _BenefitCard(
                    icon: Icons.skip_next_rounded,
                    title: 'Zero Wait',
                    subtitle: 'Skip the queue completely',
                    gradStart: const Color(0xFF004D40),
                    gradEnd: const Color(0xFF00897B),
                    delay: 520,
                  ),
                  const SizedBox(width: 12),
                  _BenefitCard(
                    icon: Icons.timer_rounded,
                    title: 'Ready On Time',
                    subtitle: 'Food prepared before you arrive',
                    gradStart: const Color(0xFF006064),
                    gradEnd: const Color(0xFF00ACC1),
                    delay: 620,
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  _BenefitCard(
                    icon: Icons.savings_rounded,
                    title: 'Save More',
                    subtitle: 'No ₹1 ASAP surcharge',
                    gradStart: const Color(0xFF4527A0),
                    gradEnd: const Color(0xFF7C4DFF),
                    delay: 720,
                  ),
                  const SizedBox(width: 12),
                  _BenefitCard(
                    icon: Icons.local_fire_department_rounded,
                    title: 'Hot & Fresh',
                    subtitle: 'Perfect timing for your meal',
                    gradStart: const Color(0xFFBF360C),
                    gradEnd: const Color(0xFFFF7043),
                    delay: 820,
                  ),
                ]),
              ],
            ),
          ),

          const SizedBox(height: 32),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF004D40), Color(0xFF00897B)],
                  ),
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF004D40).withValues(alpha: 0.38),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(100),
                    onTap: () => Navigator.pop(context),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 17),
                      child: Text(
                        'Got it — let me order!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ).animate().fadeIn(delay: 900.ms, duration: 450.ms).slideY(
                begin: 0.1,
                curve: Curves.easeOutCubic,
              ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 18),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  BENEFIT CARD
// ══════════════════════════════════════════════════════════════════
class _BenefitCard extends StatelessWidget {
  const _BenefitCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradStart,
    required this.gradEnd,
    required this.delay,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color gradStart;
  final Color gradEnd;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppTheme.backgroundLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [gradStart, gradEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Center(child: Icon(icon, color: Colors.white, size: 19)),
            ),
            const SizedBox(height: 11),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textMuted,
                height: 1.45,
              ),
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(delay: Duration(milliseconds: delay), duration: 380.ms)
          .slideY(begin: 0.12, curve: Curves.easeOutCubic),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  CLOCK ARC PAINTER
// ══════════════════════════════════════════════════════════════════
class _ClockArcPainter extends CustomPainter {
  final double progress;
  _ClockArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2 - 10;

    // Track ring
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = const Color(0xFFE0F2F1)
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    if (progress <= 0) return;

    // Gradient arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: -math.pi / 2 + 2 * math.pi,
          colors: const [
            Color(0xFF004D40),
            Color(0xFF00897B),
            Color(0xFF4DB6AC),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );

    // Glowing tip
    if (progress > 0.03) {
      final tipAngle = -math.pi / 2 + 2 * math.pi * progress;
      final tip = Offset(
        center.dx + r * math.cos(tipAngle),
        center.dy + r * math.sin(tipAngle),
      );
      canvas.drawCircle(
        tip,
        10,
        Paint()
          ..color = const Color(0xFF4DB6AC).withValues(alpha: 0.35 * progress)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
      canvas.drawCircle(tip, 4.5, Paint()..color = Colors.white);
      canvas.drawCircle(tip, 3, Paint()..color = const Color(0xFF00897B));
    }
  }

  @override
  bool shouldRepaint(covariant _ClockArcPainter old) =>
      old.progress != progress;
}
