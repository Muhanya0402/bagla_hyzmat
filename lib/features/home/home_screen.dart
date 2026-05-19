import 'package:bagla/features/auth/phone_screen.dart';
import 'package:bagla/features/home/controllers/home_screen_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/home/home_app_bar.dart';
import 'package:bagla/features/orders/order_card.dart';
import 'package:bagla/features/orders/order_detail_screen.dart';
import 'package:bagla/features/orders/create_order_screen.dart';
import 'package:bagla/features/profile/top_up_modal.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:bagla/providers/auth_provider.dart';
import 'package:bagla/providers/language_provider.dart';
import 'package:bagla/providers/level_provider.dart';
import 'widgets/home_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const Color brandGreen = Color(0xFF1A7A3C);
  static const Color brandRed = Color(0xFFD32F1E);
  static const Color brandDark = Color(0xFF111111);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [brandGreen, brandRed],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with HomeScreenController<HomeScreen> {
  static const List<StatusFilterItem> _statusFilters = [
    StatusFilterItem(label: 'Все', value: null, color: Color(0xFF9AA3AF)),
    StatusFilterItem(
      label: 'Свободные',
      value: 'published',
      color: HomeScreen.brandRed,
    ),
    StatusFilterItem(
      label: 'В работе',
      value: 'active',
      color: HomeScreen.brandGreen,
    ),
    StatusFilterItem(
      label: 'Доставлены',
      value: 'completed',
      color: Color(0xFF1A7A3C),
    ),
    StatusFilterItem(
      label: 'Отменены',
      value: 'canceled',
      color: Color(0xFF9AA3AF),
    ),
  ];

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

  void _showLevelUpOnHomeScreen(BuildContext ctx, LevelProvider provider) {
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

    final String currentStatus = authProv.status.toLowerCase().trim();
    final String role = authProv.role.toLowerCase().trim();

    final bool isActive = currentStatus == 'active';
    final bool isShop = role == 'shop' || role == 'business';
    final bool isCourier = role == 'courier';
    final bool isClient = role == 'client';
    final bool isBanned = currentStatus == 'banned';
    final bool isPending = currentStatus == 'pending' && (isCourier || isShop);
    final bool needsRoleSelection = isClient && currentStatus == 'published';

    final List<dynamic> filteredOrders = applyFilters(orders);

    return Consumer<LevelProvider>(
      builder: (context, levelProvider, child) {
        if (isCourier && levelProvider.pendingLevelUp != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showLevelUpOnHomeScreen(context, levelProvider);
          });
        }
        return child!;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          title: _buildLogoRow(authProv),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(0.5),
            child: Container(height: 0.5, color: const Color(0xFFEEF0F3)),
          ),
          actions: [
            HomeAppBarIcon(
              icon: Icons.notifications_active_outlined,
              onTap: () => Navigator.pushNamed(
                context,
                '/notifications',
              ).then((_) => handleRefresh()),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: HomeAppBarIcon(
                icon: Icons.person_outline_rounded,
                onTap: () => Navigator.pushNamed(
                  context,
                  '/profile',
                ).then((_) => handleRefresh()),
              ),
            ),
          ],
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
                child: _buildSegmentedFilter(words),
              ),
            if (isBanned || isPending)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _buildStatusBanner(isBanned),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Row(
                children: [
                  GradientText(
                    text: isShop ? words.myOrders : words.availiblorders,
                    style: AppText.semiBold(fontSize: 20, color: Colors.black),
                  ),
                  const Spacer(),
                  if (isCourier) ...[
                    HomeFilterButton(
                      activeCount: filters.activeCount,
                      onTap: showFilterModal,
                    ),
                    const SizedBox(width: 8),
                    ActiveOrdersCounter(current: activeOrdersCount, max: 3),
                  ],
                ],
              ),
            ),
            if (isShop || selectedFilterIndex == 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 0, 0),
                child: _buildStatusFilterRow(),
              ),
            const SizedBox(height: 10),
            Expanded(
              child: RefreshIndicator(
                color: HomeScreen.brandGreen,
                backgroundColor: Colors.white,
                onRefresh: handleRefresh,
                child: _buildOrdersList(
                  filteredOrders,
                  isShop,
                  authProv,
                  words,
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: (isShop && isActive)
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: _buildCreateButton(context, words),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildLogoRow(AuthProvider authProv) {
    final String role = authProv.role.toLowerCase().trim();
    final String status = authProv.status.toLowerCase().trim();
    final bool isClient = role == 'client';
    final bool needsRoleSelection = isClient && status == 'published';
    final bool isCourier = role == 'courier';

    return Row(
      mainAxisSize: MainAxisSize.min,
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
        const SizedBox(width: 8),
        if (needsRoleSelection)
          const SizedBox.shrink()
        else if (isCourier)
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
                  width: 22,
                  height: 22,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.toll_rounded,
                    size: 20,
                    color: HomeScreen.brandGreen,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  authProv.balancePoints.toDouble().toStringAsFixed(2),
                  style: AppText.semiBold(
                    fontSize: 15,
                    color: HomeScreen.brandGreen,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSegmentedFilter(AppLocalizations words) {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEF0F3)),
      ),
      child: Row(
        children: [
          _filterItem(0, words.availiblorders),
          _filterItem(1, words.myOrders),
        ],
      ),
    );
  }

  Widget _filterItem(int index, String label) {
    final bool sel = selectedFilterIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (selectedFilterIndex == index) return;
          setState(() {
            changeFilterIndex(index);
            ordersLoading = true;
          });
          reconnectRealtime();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: sel ? HomeScreen.brandGradient : null,
            color: sel ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: AppText.medium(
              fontSize: 13,
              color: sel ? Colors.white : const Color(0xFF9AA3AF),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        children: _statusFilters.map((f) {
          final bool sel = selectedStatus == f.value;
          return GestureDetector(
            onTap: () => setState(() => selectedStatus = f.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? f.color.withValues(alpha: 0.1) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sel
                      ? f.color.withValues(alpha: 0.4)
                      : const Color(0xFFEEF0F3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (sel) ...[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: f.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    f.label,
                    style: sel
                        ? AppText.semiBold(fontSize: 12, color: f.color)
                        : AppText.medium(
                            fontSize: 12,
                            color: const Color(0xFF9AA3AF),
                          ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusBanner(bool isBanned) {
    final color = isBanned ? HomeScreen.brandRed : const Color(0xFFE67E22);
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

  Widget _buildOrdersList(
    List<dynamic> ordersList,
    bool isShop,
    AuthProvider authProv,
    dynamic words,
  ) {
    if (ordersLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: HomeScreen.brandGreen,
          strokeWidth: 2,
        ),
      );
    }
    if (ordersError) {
      return const HomeEmptyState(
        icon: Icons.wifi_off_rounded,
        text: 'Ошибка загрузки. Потяните вниз.',
      );
    }
    if (ordersList.isEmpty) {
      return HomeEmptyState(
        icon: Icons.inbox_rounded,
        text: isShop ? 'У вас пока нет заказов' : words.emptyList,
      );
    }
    return ListView.builder(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      itemCount: ordersList.length + 1,
      itemBuilder: (context, index) {
        if (index == ordersList.length) {
          if (loadingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(
                  color: HomeScreen.brandGreen,
                  strokeWidth: 2,
                ),
              ),
            );
          }
          if (!hasMore && ordersList.isNotEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Все заказы загружены',
                  style: AppText.regular(
                    fontSize: 12,
                    color: const Color(0xFF9AA3AF),
                  ),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }
        return OrderCard(
          order: ordersList[index],
          role: isShop ? 'shop' : 'courier',
          currentUserId: authProv.userId,
          userPhone: authProv.phone,
          onUpdate: handleRefresh,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen(
                order: ordersList[index],
                role: isShop ? 'shop' : 'courier',
                currentUserId: authProv.userId,
                onUpdate: handleRefresh,
              ),
            ),
          ).then((_) => handleRefresh()),
        );
      },
    );
  }

  Widget _buildCreateButton(BuildContext context, AppLocalizations words) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
      ).then((_) => handleRefresh()),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: HomeScreen.brandGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: HomeScreen.brandGreen.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              words.createOrder,
              style: AppText.medium(
                fontSize: 15,
                color: Colors.white,
              ).copyWith(letterSpacing: 0.2),
            ),
          ],
        ),
      ),
    );
  }
}
