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

    // Set restaurant context (will fail silently if different restaurant already in cart)
    cart.setRestaurant(dish.restaurantId, dish.restaurantName);

    // Check if cart has items from a different restaurant
    if (cart.restaurantId != null &&
        cart.restaurantId != dish.restaurantId &&
        !cart.isEmpty) {
      // Show a dialog asking to replace cart
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius2XL),
          ),
          title: const Text('Replace cart?'),
          content: Text(
            'Your cart has items from ${cart.restaurantName}. Adding this item will clear your current cart.',
          ),
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
                cart.setRestaurant(dish.restaurantId, dish.restaurantName);
                cart.addItem(menuItem: dish.item);
                Navigator.pop(ctx);
              },
              child: const Text(
                'Replace',
                style: TextStyle(
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }

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
}
