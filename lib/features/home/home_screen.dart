import 'package:bagla/features/auth/phone_screen.dart';
import 'package:bagla/features/home/controllers/home_screen_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bagla/core/app_text_styles.dart';
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
    final levelProvider = context.watch<LevelProvider>();

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

    if (isCourier && levelProvider.pendingLevelUp != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showLevelUpOnHomeScreen(context, levelProvider);
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: _buildLogoRow(authProv, levelProvider),
        actions: [
          // ── Счётчик активных заказов в AppBar (только для курьера) ────────
          if (isCourier)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _ActiveOrdersBadge(current: activeOrdersCount, max: 3),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: const Color(0xFFEEF0F3)),
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

          // ── Сегментный фильтр + кнопка фильтра в одной строке ─────────────
          if (isCourier)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _buildSegmentedFilterWithButton(words),
            ),

          // ── Полоса уровня (только для курьера) ────────────────────────────
          if (isBanned || isPending)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _buildStatusBanner(isBanned),
            ),
          if (isShop)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Row(
                children: [
                  // Фильтр для магазина остаётся здесь (курьерский — уже в сегменте)
                  HomeFilterButton(
                    activeCount: filters.activeCount,
                    onTap: showFilterModal,
                  ),
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
              child: _buildOrdersList(filteredOrders, isShop, authProv, words),
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
    );
  }

  // ── AppBar logo row ────────────────────────────────────────────────────────
  Widget _buildLogoRow(AuthProvider authProv, LevelProvider levelProvider) {
    final String role = authProv.role.toLowerCase().trim();
    final String status = authProv.status.toLowerCase().trim();

    final bool isClient = role == 'client';
    final bool needsRoleSelection = isClient && status == 'published';
    final bool isCourier = role == 'courier';

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

          // ─── Progress bar ───
          Expanded(child: _CompactLevelProgressBar(provider: levelProvider)),

          const SizedBox(width: 10),

          // ─── Balance ───
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
                    color: HomeScreen.brandGreen,
                  ),
                ),

                const SizedBox(width: 4),

                Text(
                  authProv.balancePoints.toDouble().toStringAsFixed(2),
                  style: AppText.semiBold(
                    fontSize: 14,
                    color: HomeScreen.brandGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Сегментный фильтр + кнопка фильтра ────────────────────────────────────
  Widget _buildSegmentedFilterWithButton(AppLocalizations words) {
    return Row(
      children: [
        // Сегментный переключатель
        Expanded(
          child: Container(
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
          ),
        ),
        const SizedBox(width: 8),
        // Кнопка фильтра
        _FilterIconButton(
          activeCount: filters.activeCount,
          onTap: showFilterModal,
        ),
      ],
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

  // ── Status filter chips ────────────────────────────────────────────────────
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
              settings: const RouteSettings(name: '/order_detail'),
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

// ═════════════════════════════════════════════════════════════════════════════
// Счётчик активных заказов в AppBar
// ═════════════════════════════════════════════════════════════════════════════
class _ActiveOrdersBadge extends StatelessWidget {
  final int current;
  final int max;

  const _ActiveOrdersBadge({required this.current, required this.max});

  @override
  Widget build(BuildContext context) {
    final bool isFull = current >= max;
    final Color color = isFull ? HomeScreen.brandRed : HomeScreen.brandGreen;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_shipping_outlined, size: 14, color: color),
          const SizedBox(width: 5),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$current',
                  style: AppText.bold(fontSize: 13, color: color),
                ),
                TextSpan(
                  text: '/$max',
                  style: AppText.regular(
                    fontSize: 12,
                    color: color.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Кнопка фильтра (иконка с бейджем)
// ═════════════════════════════════════════════════════════════════════════════
class _FilterIconButton extends StatelessWidget {
  final int activeCount;
  final VoidCallback onTap;

  const _FilterIconButton({required this.activeCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: activeCount > 0
                    ? HomeScreen.brandGreen.withValues(alpha: 0.4)
                    : const Color(0xFFEEF0F3),
              ),
            ),
            child: Icon(
              Icons.tune_rounded,
              size: 20,
              color: activeCount > 0
                  ? HomeScreen.brandGreen
                  : const Color(0xFF9AA3AF),
            ),
          ),
          if (activeCount > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: HomeScreen.brandGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$activeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Полоса прогресса уровня
// ═════════════════════════════════════════════════════════════════════════════
class _CompactLevelProgressBar extends StatelessWidget {
  final LevelProvider provider;

  const _CompactLevelProgressBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    final int level = provider.currentLevel?.levelNumber ?? 1;
    final int xp = provider.currentXp;
    final int xpNeeded = provider.xpToNextLevel;

    final double progress = xpNeeded > 0
        ? (xp / xpNeeded).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F7),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // ─── Progress ───
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            width: MediaQuery.of(context).size.width * 0.42 * progress,
            height: 24,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [HomeScreen.brandGreen, const Color(0xFF2BBE63)],
              ),
              borderRadius: BorderRadius.circular(100),
              boxShadow: [
                BoxShadow(
                  color: HomeScreen.brandGreen.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
          ),

          // ─── Content ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                // Current level
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$level',
                    style: AppText.extraBold(
                      fontSize: 9,
                      color: HomeScreen.brandGreen,
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                // XP
                Expanded(
                  child: Center(
                    child: Text(
                      '$xp/$xpNeeded XP',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.semiBold(
                        fontSize: 9,
                        color: progress > 0.55
                            ? Colors.white
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 4),

                // next level
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: progress > 0.88
                        ? Colors.white.withValues(alpha: 0.16)
                        : HomeScreen.brandGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.keyboard_arrow_up_rounded,
                        size: 10,
                        color: progress > 0.88
                            ? Colors.white
                            : HomeScreen.brandGreen,
                      ),
                      Text(
                        '${level + 1}',
                        style: AppText.extraBold(
                          fontSize: 8,
                          color: progress > 0.88
                              ? Colors.white
                              : HomeScreen.brandGreen,
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
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  final double progress;
  const _ProgressTrack({required this.progress});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth;
        final double filledWidth = (totalWidth * progress).clamp(
          0.0,
          totalWidth,
        );

        return Container(
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F4F8),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                width: filledWidth,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [HomeScreen.brandGreen, Color(0xFF34D46A)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: HomeScreen.brandGreen.withValues(alpha: 0.35),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
