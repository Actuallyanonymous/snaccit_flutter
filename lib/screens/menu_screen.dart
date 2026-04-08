import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';
import '../models/restaurant.dart';
import '../models/menu_item.dart';
import '../providers/restaurant_provider.dart';
import '../providers/cart_provider.dart';
import '../widgets/cart_dock.dart';

class MenuScreen extends StatefulWidget {
  final Restaurant restaurant;

  const MenuScreen({super.key, required this.restaurant});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _activeCategory = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Get the display price for a menu item (uses sizes[0].price if available)
  double _getItemDisplayPrice(MenuItem item) {
    if (item.sizes != null && item.sizes!.isNotEmpty) {
      return item.sizes!.first.price;
    }
    return item.price;
  }

  void _addToCart(MenuItem item) {
    HapticFeedback.lightImpact();
    if ((item.sizes != null && item.sizes!.isNotEmpty) ||
        (item.addons != null && item.addons!.isNotEmpty)) {
      _showCustomizationModal(item);
    } else {
      context.read<CartProvider>().addItem(
        menuItem: item,
      );
    }
  }

  void _showCustomizationModal(MenuItem item) {
    String? selectedSize = item.sizes?.first.name;
    List<MenuItemAddon> selectedAddons = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Use size price as primary
          double totalPrice = 0;
          if (selectedSize != null && item.sizes != null) {
            final size = item.sizes!.firstWhere((s) => s.name == selectedSize);
            totalPrice = size.price;
          } else if (item.sizes != null && item.sizes!.isNotEmpty) {
            totalPrice = item.sizes!.first.price;
          } else {
            totalPrice = item.price;
          }
          for (final addon in selectedAddons) {
            totalPrice += addon.price;
          }

          return Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceWhite,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: SafeArea(
              top: false,
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

                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            // Veg indicator
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: item.isVeg ? Colors.green : Colors.red,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Center(
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: item.isVeg
                                        ? Colors.green
                                        : Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close,
                                  size: 18,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),

                        if (item.description != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            item.description!,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Sizes
                        if (item.sizes != null && item.sizes!.isNotEmpty) ...[
                          Text(
                            'SIZE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textMuted,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...item.sizes!.map((size) {
                            final isSelected = selectedSize == size.name;
                            return GestureDetector(
                              onTap: () =>
                                  setModalState(() => selectedSize = size.name),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.emerald50
                                      : AppTheme.surfaceWhite,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusLarge,
                                  ),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.primaryGreen
                                        : AppTheme.border.withValues(
                                            alpha: 0.5,
                                          ),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? AppTheme.shadowCard
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected
                                              ? AppTheme.primaryGreen
                                              : AppTheme.textHint,
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
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        size.name,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '₹${size.price.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? AppTheme.primaryGreen
                                            : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 12),
                        ],

                        // Addons
                        if (item.addons != null && item.addons!.isNotEmpty) ...[
                          Text(
                            'ADD-ONS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textMuted,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...item.addons!.map((addon) {
                            final isSelected = selectedAddons.contains(addon);
                            return GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  if (isSelected) {
                                    selectedAddons.remove(addon);
                                  } else {
                                    selectedAddons.add(addon);
                                  }
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.emerald50
                                      : AppTheme.surfaceWhite,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusLarge,
                                  ),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.primaryGreen
                                        : AppTheme.border.withValues(
                                            alpha: 0.5,
                                          ),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? AppTheme.shadowCard
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppTheme.primaryGreen
                                              : AppTheme.textHint,
                                          width: 2,
                                        ),
                                        color: isSelected
                                            ? AppTheme.primaryGreen
                                            : Colors.transparent,
                                      ),
                                      child: isSelected
                                          ? const Icon(
                                              Icons.check,
                                              size: 14,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        addon.name,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '+₹${addon.price.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? AppTheme.primaryGreen
                                            : AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                        ],

                        const SizedBox(height: 8),

                        // Add to cart button
                        GestureDetector(
                          onTap: () {
                            context.read<CartProvider>().addItem(
                              menuItem: item,
                              selectedSize: selectedSize,
                              selectedAddons: selectedAddons,
                            );
                            Navigator.pop(context);
                          },
                          child: Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: AppTheme.buttonGradient,
                              borderRadius: BorderRadius.circular(100),
                              boxShadow: AppTheme.shadowGreen,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Add to Cart · ₹${totalPrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ─── App Bar with Restaurant Hero ───
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: AppTheme.surfaceWhite,
                foregroundColor: Colors.white,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(
                    left: 20,
                    bottom: 16,
                    right: 20,
                  ),
                  title: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.restaurant.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 8),
                          ],
                        ),
                      ),
                      if (widget.restaurant.rating != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 12,
                              color: AppTheme.accentYellow,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${widget.restaurant.rating!.toStringAsFixed(1)} · ${widget.restaurant.reviewCount ?? 0} reviews',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white70,
                                shadows: [
                                  Shadow(color: Colors.black54, blurRadius: 4),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      widget.restaurant.imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: widget.restaurant.imageUrl!,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              decoration: const BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.restaurant_rounded,
                                  size: 48,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.1),
                              Colors.black.withValues(alpha: 0.6),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Search Bar ───
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceWhite,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: AppTheme.border.withValues(alpha: 0.4),
                      ),
                      boxShadow: AppTheme.shadowSoft,
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        filled: false,
                        hintText: 'Search menu items...',
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: _searchQuery.isNotEmpty
                              ? AppTheme.primaryGreen
                              : AppTheme.textHint,
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
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ─── Quick Bites Suggestions ───
              Consumer<RestaurantProvider>(
                builder: (context, provider, _) {
                  final quickItems = provider.menuItems.where((i) => i.isExpress).toList();
                  if (quickItems.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.bolt_rounded, size: 16, color: AppTheme.primaryGreen),
                              const SizedBox(width: 6),
                              const Text(
                                'Quick Bites',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Ready in ~5 min',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 88,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: quickItems.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final item = quickItems[index];
                                return GestureDetector(
                                  onTap: () => _addToCart(item),
                                  child: Container(
                                    width: 140,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceWhite,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
                                      boxShadow: AppTheme.shadowCard,
                                    ),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            item.imageUrl ?? 'https://placehold.co/200',
                                            width: 44,
                                            height: 44,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              width: 44, height: 44,
                                              color: AppTheme.backgroundLight,
                                              child: const Icon(Icons.fastfood_rounded, size: 22, color: AppTheme.textMuted),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                item.name,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppTheme.textPrimary,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                '₹${(item.sizes != null && item.sizes!.isNotEmpty ? item.sizes!.first.price : item.price).toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppTheme.primaryGreen,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // ─── Category Tabs ───
              Consumer<RestaurantProvider>(
                builder: (context, provider, _) {
                  if (provider.menuByCategory.isEmpty) {
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  }

                  final categories = ['All', ...provider.menuByCategory.keys];

                  return SliverToBoxAdapter(
                    child: SizedBox(
                      height: 60,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          final isActive = _activeCategory == cat;

                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _activeCategory = cat);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppTheme.primaryGreen
                                    : AppTheme.surfaceWhite,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: isActive
                                      ? AppTheme.primaryGreen
                                      : AppTheme.border.withValues(alpha: 0.5),
                                ),
                                boxShadow: isActive
                                    ? AppTheme.shadowGreen
                                    : AppTheme.shadowCard,
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isActive) ...[
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    cat.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isActive
                                          ? Colors.white
                                          : AppTheme.textMuted,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),

              // ─── Menu Items ───
              Consumer<RestaurantProvider>(
                builder: (context, provider, _) {
                  if (provider.isMenuLoading) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: AppTheme.primaryGreen,
                              strokeWidth: 3,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Loading menu...',
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

                  List<MenuItem> items;
                  if (_searchQuery.isNotEmpty) {
                    items = provider.searchMenu(_searchQuery);
                  } else if (_activeCategory == 'All') {
                    items = provider.menuItems;
                  } else {
                    items = provider.menuByCategory[_activeCategory] ?? [];
                  }

                  if (items.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.restaurant_menu_rounded,
                              size: 48,
                              color: AppTheme.primaryGreen,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No items match "$_searchQuery"'
                                  : 'No items in this category',
                              style: TextStyle(
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildMenuItem(items[index], index),
                        childCount: items.length,
                      ),
                    ),
                  );
                },
              ),

              // Bottom padding for cart dock
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),

          // ─── Cart Dock ───
          const CartDock(),
        ],
      ),
    );
  }

  Widget _buildMenuItem(MenuItem item, int index) {
    final isUnavailable = !item.isAvailable;

    return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(AppTheme.radius2XL),
            border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
            boxShadow: AppTheme.shadowCard,
          ),
          child: Opacity(
            opacity: isUnavailable ? 0.5 : 1.0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                  child: SizedBox(
                    width: 110,
                    height: 110,
                    child: item.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: item.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: AppTheme.divider,
                              child: const Center(
                                child: Icon(
                                  Icons.restaurant,
                                  color: AppTheme.textHint,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color: AppTheme.emerald50,
                            child: const Center(
                              child: Icon(
                                Icons.restaurant_rounded,
                                size: 32,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ),
                  ),
                ),

                const SizedBox(width: 14),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Veg/Non-veg + Name
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 3),
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: item.isVeg ? Colors.green : Colors.red,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Center(
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: item.isVeg ? Colors.green : Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      if (item.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.description!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      const SizedBox(height: 10),

                      // Price + Add button
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '₹${_getItemDisplayPrice(item).toStringAsFixed(0)}${item.sizes != null && item.sizes!.length > 1 ? '+' : ''}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Add button
                          GestureDetector(
                            onTap: () =>
                                !isUnavailable ? _addToCart(item) : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: isUnavailable
                                    ? Colors.grey.shade100
                                    : AppTheme.emerald50,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: isUnavailable
                                      ? Colors.grey.shade200
                                      : AppTheme.primaryGreenLight,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isUnavailable ? 'UNAVAILABLE' : 'ADD',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: isUnavailable
                                          ? AppTheme.textMuted
                                          : AppTheme.primaryGreen,
                                    ),
                                  ),
                                  if (!isUnavailable) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.add,
                                      size: 16,
                                      color: AppTheme.primaryGreen,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
        .animate(delay: Duration(milliseconds: 40 * (index % 8)))
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.03);
  }
}
