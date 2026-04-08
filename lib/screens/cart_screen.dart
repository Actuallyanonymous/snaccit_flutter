import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/theme.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/restaurant_provider.dart';
import '../models/menu_item.dart';
import 'checkout_screen.dart';
import 'auth_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  // Food fact state
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

  @override
  void initState() {
    super.initState();
    _currentFact = _foodFacts[Random().nextInt(_foodFacts.length)];
    _loadSuggestions();
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWhite,
        title: const Text('Your Cart'),
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
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusLarge,
                        ),
                      ),
                    ),
                    child: const Text('Browse Restaurants'),
                  ),
                ],
              ).animate().fadeIn(),
            );
          }

          return Column(
            children: [
              // Restaurant header
              if (cart.restaurantName != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
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

              // Scrollable content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // Cart items
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
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusXL,
                                ),
                                border: Border.all(
                                  color: AppTheme.border.withValues(alpha: 0.3),
                                ),
                                boxShadow: AppTheme.shadowCard,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
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
                            ) /* closes Container */,
                          )
                          .animate(
                            delay: Duration(milliseconds: 60 * index),
                          ) /* closes AnimatedSize */
                          .fadeIn(duration: 300.ms)
                          .slideX(begin: 0.03);
                    }),

                    const SizedBox(height: 8),

                    // ─── Food Fact Card ───
                    _buildFoodFactCard(),

                    // ─── Suggestions ───
                    if (_suggestionsLoaded && _suggestions.isNotEmpty)
                      _buildSuggestionsSection(cart),

                    const SizedBox(height: 24),

                    // ─── Bill Summary ───
                    _buildBillSummary(cart),

                    const SizedBox(height: 100),
                  ],
                ),
              ),

              // ─── Bottom Bar ───
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
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
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${cart.itemCount} items',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₹${cart.subtotal.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            final auth = context.read<AuthProvider>();
                            if (!auth.isLoggedIn) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AuthScreen(),
                                ),
                              );
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CheckoutScreen(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: AppTheme.buttonGradient,
                              borderRadius: BorderRadius.circular(100),
                              boxShadow: AppTheme.shadowGreen,
                            ),
                            alignment: Alignment.center,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Checkout',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(
                                  Icons.arrow_forward,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ],
                            ),
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

  // ─── Bill Summary ───
  Widget _buildBillSummary(CartProvider cart) {
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
            'Bill Details',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(cart.items.length, (i) {
            final item = cart.items[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${item.name} x${item.quantity}',
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
            );
          }),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              const dashWidth = 4.0;
              final dashCount = (constraints.constrainWidth() / (2 * dashWidth))
                  .floor();
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
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              Text(
                '₹${cart.subtotal.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
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
              child: Icon(
                Icons.refresh_rounded,
                size: 16,
                color: AppTheme.textMuted,
              ),
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
            const Icon(
              Icons.auto_awesome,
              size: 16,
              color: AppTheme.primaryGreen,
            ),
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
          final displayPrice = (item.sizes != null && item.sizes!.isNotEmpty)
              ? item.sizes!.first.price
              : item.price;

          return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWhite,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                  border: Border.all(
                    color: AppTheme.border.withValues(alpha: 0.2),
                  ),
                  boxShadow: AppTheme.shadowSm,
                ),
                child: Row(
                  children: [
                    // Small image
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
                            Icon(
                              Icons.add_rounded,
                              size: 16,
                              color: AppTheme.primaryGreen,
                            ),
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
