import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/theme.dart';
import '../models/restaurant.dart';
import '../providers/restaurant_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/restaurant_card.dart';
import 'menu_screen.dart';
import 'auth_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Start listening if not already
    final provider = context.read<RestaurantProvider>();
    if (provider.restaurants.isEmpty) {
      provider.listenToRestaurants();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onRestaurantTap(Restaurant restaurant) {
    // Owner has explicitly closed the restaurant — block access
    if (!restaurant.isOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.cancel, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Text('This restaurant is currently closed'),
            ],
          ),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
        ),
      );
      return;
    }

    // Time-closed restaurants are allowed — user can browse menu
    // (ordering is prevented at checkout by empty time slots)

    context.read<RestaurantProvider>().selectRestaurant(restaurant);
    context.read<CartProvider>().setRestaurant(restaurant.id, restaurant.name);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MenuScreen(restaurant: restaurant),
      ),
    );
  }

  void _goToProfile() {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              // ─── Header ───
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Greeting
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getGreeting(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryGreen,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Consumer<AuthProvider>(
                                  builder: (context, auth, _) => Text(
                                    auth.isLoggedIn
                                        ? (auth.userProfile?.name ?? 'Foodie')
                                        : 'Hungry?',
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Profile avatar
                          GestureDetector(
                            onTap: _goToProfile,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppTheme.emerald50,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.primaryGreenLight, width: 2),
                              ),
                              child: Consumer<AuthProvider>(
                                builder: (context, auth, _) => Center(
                                  child: auth.isLoggedIn
                                      ? Text(
                                          (auth.userProfile?.name ?? 'U')[0].toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.primaryGreen,
                                          ),
                                        )
                                      : const Icon(Icons.person_outline, color: AppTheme.primaryGreen, size: 22),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ─── Search Bar ───
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceWhite,
                          borderRadius: BorderRadius.circular(AppTheme.radius2XL),
                          border: Border.all(color: AppTheme.border.withValues(alpha: 0.4)),
                          boxShadow: AppTheme.shadowSoft,
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _searchQuery = v),
                          decoration: InputDecoration(
                            hintText: 'Search restaurants...',
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: _searchQuery.isNotEmpty ? AppTheme.primaryGreen : AppTheme.textHint,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 20),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Section title
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Explore Restaurants',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ).animate().fadeIn(duration: 500.ms),
              ),

              // ─── Restaurant List ───
              Consumer<RestaurantProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                color: AppTheme.primaryGreen,
                                strokeWidth: 3,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Loading restaurants...',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Filter by visibility + search
                  var restaurants = provider.restaurants
                      .where((r) => r.isVisible)
                      .toList();

                  if (_searchQuery.isNotEmpty) {
                    restaurants = restaurants
                        .where((r) => r.name.toLowerCase().contains(_searchQuery.toLowerCase()))
                        .toList();
                  }

                  // Sort: open+inHours first, then time-closed, then owner-closed
                  restaurants.sort((a, b) {
                    int priority(Restaurant r) {
                      if (r.isOpen && r.isCurrentlyInHours) return 0; // Fully open
                      if (r.isTimeClosed) return 1; // Outside hours but operational
                      return 2; // Owner closed
                    }
                    return priority(a).compareTo(priority(b));
                  });

                  if (restaurants.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🔍', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 16),
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
                          ],
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final restaurant = restaurants[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: RestaurantCard(
                              restaurant: restaurant,
                              onTap: () => _onRestaurantTap(restaurant),
                            ),
                          );
                        },
                        childCount: restaurants.length,
                      ),
                    ),
                  );
                },
              ),

              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),

        // ─── Cart FAB ───
        floatingActionButton: Consumer<CartProvider>(
          builder: (context, cart, _) {
            if (cart.isEmpty) return const SizedBox.shrink();

            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppTheme.buttonGradient,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: AppTheme.shadowGreen,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      '₹${cart.subtotal.toStringAsFixed(0)} · ${cart.itemCount} items',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().slideY(begin: 1, duration: 400.ms, curve: Curves.easeOut);
          },
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning 🌅';
    if (hour < 17) return 'Good Afternoon ☀️';
    return 'Good Evening 🌙';
  }
}
