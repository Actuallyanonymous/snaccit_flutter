import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../models/order.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _nameController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn) {
      context.read<OrderProvider>().listenToOrders(auth.firebaseUser!.uid);
      _nameController.text = auth.userProfile?.name ?? '';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    await context.read<AuthProvider>().updateProfile(name: _nameController.text);
    setState(() => _isEditing = false);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radius2XL)),
        title: const Text('Logout?'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout', style: TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await context.read<AuthProvider>().signOut();
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) => Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: AppBar(
          backgroundColor: AppTheme.surfaceWhite,
          title: const Text('Profile'),
          actions: [
            TextButton.icon(
              onPressed: _logout,
              icon: Icon(Icons.logout, size: 18, color: AppTheme.errorRed.withValues(alpha: 0.7)),
              label: Text(
                'Logout',
                style: TextStyle(
                  color: AppTheme.errorRed.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryGreen,
            unselectedLabelColor: AppTheme.textMuted,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            indicatorColor: AppTheme.primaryGreen,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [
              Tab(text: 'Profile'),
              Tab(text: 'Orders'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildProfileTab(auth),
            _buildOrdersTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab(AuthProvider auth) {
    final user = auth.userProfile;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // ─── Avatar ───
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: AppTheme.shadowGreen,
            ),
            child: Center(
              child: Text(
                (user?.name ?? 'U')[0].toUpperCase(),
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ).animate().scale(duration: 400.ms, curve: Curves.easeOut),

          const SizedBox(height: 24),

          // ─── Name Card ───
          _buildInfoCard(
            icon: Icons.person_outline,
            title: 'Name',
            value: user?.name ?? 'Customer',
            isEditing: _isEditing,
            editWidget: TextField(
              controller: _nameController,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            onEdit: () => setState(() => _isEditing = true),
            onSave: _saveName,
            onCancel: () {
              _nameController.text = user?.name ?? '';
              setState(() => _isEditing = false);
            },
          ),

          const SizedBox(height: 12),

          // ─── Phone Card ───
          _buildInfoCard(
            icon: Icons.phone_outlined,
            title: 'Phone',
            value: auth.firebaseUser?.phoneNumber ?? 'Not set',
          ),

          const SizedBox(height: 16),

          // ─── Points Card ───
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(AppTheme.radius2XL),
              boxShadow: AppTheme.shadowGreen,
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(child: Text('🎁', style: TextStyle(fontSize: 26))),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SNACCIT POINTS',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${user?.points ?? 0} pts',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '≈ ₹${((user?.points ?? 0) / 10).toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),

          const SizedBox(height: 12),

          // ─── Referral Code ───
          if (user?.referralCode != null)
            _buildInfoCard(
              icon: Icons.card_giftcard,
              title: 'Your Referral Code',
              value: user!.referralCode!,
              trailing: GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: user.referralCode!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          const Text('Copied to clipboard!'),
                        ],
                      ),
                      backgroundColor: AppTheme.primaryGreen,
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.emerald50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.copy, size: 18, color: AppTheme.primaryGreen),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    bool isEditing = false,
    Widget? editWidget,
    VoidCallback? onEdit,
    VoidCallback? onSave,
    VoidCallback? onCancel,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
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
            child: Icon(icon, color: AppTheme.primaryGreen, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textMuted,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                if (isEditing && editWidget != null)
                  editWidget
                else
                  Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.textPrimary),
                  ),
              ],
            ),
          ),
          if (isEditing) ...[
            GestureDetector(
              onTap: onSave,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.emerald50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check, color: AppTheme.primaryGreen, size: 18),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onCancel,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.close, color: AppTheme.textMuted, size: 18),
              ),
            ),
          ] else if (onEdit != null)
            GestureDetector(
              onTap: onEdit,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.emerald50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit, size: 16, color: AppTheme.primaryGreen),
              ),
            ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildOrdersTab() {
    return Consumer<OrderProvider>(
      builder: (context, orders, _) {
        if (orders.orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppTheme.emerald50,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(child: Text('📦', style: TextStyle(fontSize: 40))),
                ),
                const SizedBox(height: 20),
                const Text(
                  'No orders yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your order history will appear here',
                  style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
                ),
              ],
            ).animate().fadeIn(),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.orders.length,
          itemBuilder: (context, index) {
            return _buildOrderCard(orders.orders[index], index);
          },
        );
      },
    );
  }

  Widget _buildOrderCard(Order order, int index) {
    Color statusColor;
    IconData statusIcon;
    switch (order.status) {
      case OrderStatus.awaitingPayment:
        statusColor = Colors.blue;
        statusIcon = Icons.hourglass_top;
        break;
      case OrderStatus.pending:
        statusColor = Colors.amber.shade700;
        statusIcon = Icons.hourglass_top;
        break;
      case OrderStatus.accepted:
        statusColor = Colors.blue;
        statusIcon = Icons.thumb_up;
        break;
      case OrderStatus.preparing:
        statusColor = Colors.indigo;
        statusIcon = Icons.restaurant;
        break;
      case OrderStatus.ready:
        statusColor = AppTheme.accentOrange;
        statusIcon = Icons.notifications_active;
        break;
      case OrderStatus.completed:
        statusColor = AppTheme.successGreen;
        statusIcon = Icons.check_circle;
        break;
      case OrderStatus.declined:
      case OrderStatus.failed:
      case OrderStatus.paymentFailed:
      case OrderStatus.paymentInitFailed:
        statusColor = AppTheme.errorRed;
        statusIcon = Icons.cancel;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  order.restaurantName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      order.statusDisplay,
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Items
          Text(
            order.items.map((i) => '${i.quantity}x ${i.name}').join(', '),
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 10),

          // Footer
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppTheme.divider))),
            child: Row(
              children: [
                Text(
                  '₹${order.total.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary),
                ),
                const Spacer(),
                if (order.createdAt != null)
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 13, color: AppTheme.textHint),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(order.createdAt!),
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: 50 * (index % 10))).fadeIn(duration: 300.ms).slideX(begin: 0.03);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Yesterday';
    }
    return '${date.day}/${date.month}/${date.year}';
  }
}
