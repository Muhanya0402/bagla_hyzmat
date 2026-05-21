import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/auth/widgets/auth_widgets.dart';
import 'package:bagla/features/home/controllers/home_screen_controller.dart';
import 'package:bagla/features/home/home_constants.dart';
import 'package:bagla/features/home/widgets/home_create_button.dart';
import 'package:bagla/features/home/widgets/home_level_bar.dart';
import 'package:bagla/features/home/widgets/home_orders_list.dart';
import 'package:bagla/features/home/widgets/home_segmented_filter.dart';
import 'package:bagla/features/home/widgets/home_status_filter.dart';
import 'package:bagla/features/home/widgets/home_widgets.dart';
import 'package:bagla/features/orders/create_order_screen.dart';
import 'package:bagla/features/profile/top_up_modal.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:bagla/features/levels/level_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with HomeScreenController<HomeScreen> {
  @override
  void initState() {
    super.initState();
    initController();
  }

  @override
  void dispose() {
    disposeController();
    super.dispose();
  }

  void _showLevelUp(BuildContext ctx, LevelProvider provider) {
    final pending = provider.pendingLevelUp;
    if (pending == null) return;
    Navigator.of(ctx)
        .push(
          PageRouteBuilder(
            opaque: false,
            barrierColor: Colors.black54,
            pageBuilder: (_, _, _) => LevelUpOverlay(
              provider: provider,
              onDismiss: () {
                provider.dismissLevelUp(pending.id);
                Navigator.of(ctx).pop();
              },
            ),
          ),
        )
        .then((_) => handleRefresh());
  }

  @override
  Widget build(BuildContext context) {
    final authProv = context.watch<AuthProvider>();
    final lang = context.watch<LanguageProvider>();
    final words = lang.words;
    final levelProvider = context.watch<LevelProvider>();

    final String role = authProv.role.toLowerCase().trim();
    final String currentStatus = authProv.status.toLowerCase().trim();

    final bool isActive = currentStatus == 'active';
    final bool isShop = role == 'shop' || role == 'business';
    final bool isCourier = role == 'courier';
    final bool isClient = role == 'client';
    final bool isBanned = currentStatus == 'banned';
    final bool isPending = currentStatus == 'pending' && (isCourier || isShop);
    final bool needsRoleSelection = isClient && currentStatus == 'published';

    final filteredOrders = applyFilters(orders);

    if (isCourier && levelProvider.pendingLevelUp != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showLevelUp(context, levelProvider);
      });
    }

    return Scaffold(
      backgroundColor: HomeColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: _buildLogoRow(authProv, levelProvider),
        actions: [
          if (isCourier)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ActiveOrdersCounter(current: activeOrdersCount, max: 3),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: HomeColors.border),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (needsRoleSelection)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: RoleSelectionBanner(
                onTap: () => Navigator.pushNamed(
                  context,
                  '/user_type_selection',
                ).then((_) => handleRefresh()),
              ),
            ),

          if (isCourier)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: HomeSegmentedFilter(
                selectedIndex: selectedFilterIndex,
                onChanged: (i) {
                  if (selectedFilterIndex == i) return;
                  setState(() {
                    changeFilterIndex(i);
                    ordersLoading = true;
                  });
                  reconnectRealtime();
                },
                filterActiveCount: filters.activeCount,
                onFilterTap: showFilterModal,
                words: words,
              ),
            ),

          if (isBanned || isPending)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _buildStatusBanner(isBanned),
            ),

          if (isShop)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: HomeFilterButton(
                activeCount: filters.activeCount,
                onTap: showFilterModal,
              ),
            ),

          if (isShop || selectedFilterIndex == 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 0, 0),
              child: HomeStatusFilter(
                selectedStatus: selectedStatus,
                onChanged: (v) => setState(() => selectedStatus = v),
              ),
            ),

          const SizedBox(height: 10),

          Expanded(
            child: RefreshIndicator(
              color: HomeColors.green,
              backgroundColor: Colors.white,
              onRefresh: handleRefresh,
              child: HomeOrdersList(
                orders: filteredOrders,
                isLoading: ordersLoading,
                hasError: ordersError,
                isShop: isShop,
                loadingMore: loadingMore,
                hasMore: hasMore,
                scrollController: scrollController,
                authProv: authProv,
                words: words,
                onRefresh: handleRefresh,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: (isShop && isActive)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: HomeCreateButton(
                  label: words.createOrder,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateOrderScreen(),
                    ),
                  ).then((_) => handleRefresh()),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildLogoRow(AuthProvider authProv, LevelProvider levelProvider) {
    final bool isCourier = authProv.role.toLowerCase() == 'courier';
    final bool isClient = authProv.role.toLowerCase() == 'client';
    final bool needsRoleSelection =
        isClient && authProv.status.toLowerCase() == 'published';

    return Row(
      children: [
        Image.asset(
          realtimeService.isConnected
              ? 'assets/images/bagla_logo.png'
              : 'assets/images/bagla_logo_gray.png',
          width: 40,
          height: 40,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const BaglaLogo(width: 48, height: 24),
        ),
        if (!needsRoleSelection && isCourier) ...[
          const SizedBox(width: 10),
          Expanded(child: HomeLevelBar(provider: levelProvider)),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => TopUpModal(
                userId: authProv.userId,
                role: authProv.role,
                status: authProv.status,
              ),
            ).then((_) => handleRefresh()),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/point_icon.png',
                  width: 20,
                  height: 20,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.toll_rounded,
                    size: 18,
                    color: HomeColors.green,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  authProv.balancePoints.toDouble().toStringAsFixed(2),
                  style: AppText.semiBold(
                    fontSize: 14,
                    color: HomeColors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusBanner(bool isBanned) {
    final color = isBanned ? HomeColors.red : const Color(0xFFE67E22);
    final bgColor = isBanned
        ? const Color(0xFFFFF0EE)
        : const Color(0xFFFFF8EE);
    final icon = isBanned ? Icons.block_rounded : Icons.access_time_rounded;
    final text = isBanned
        ? 'Аккаунт заблокирован'
        : 'Ожидание проверки модератора';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppText.medium(fontSize: 13, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
