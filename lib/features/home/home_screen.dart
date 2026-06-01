import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/core/tour/app_tour_mixin.dart';

import 'package:bagla/core/tour/tour_keys.dart';
import 'package:bagla/core/tour/tour_target.dart';
import 'package:bagla/features/home/controllers/home_screen_controller.dart';
import 'package:bagla/features/home/home_constants.dart';
import 'package:bagla/features/home/widgets/home_app_bar.dart';
import 'package:bagla/features/home/widgets/home_orders_list.dart';
import 'package:bagla/features/home/widgets/home_segmented_filter.dart';
import 'package:bagla/features/home/widgets/home_status_filter.dart';
import 'package:bagla/features/home/widgets/home_widgets.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:bagla/features/levels/level_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with HomeScreenController<HomeScreen>, AppTourMixin<HomeScreen> {
  // ── Tour anchors ──────────────────────────────────────────────────────────
  final _logoKey = GlobalKey(); // приветствие / level bar
  final _activeCounterKey = GlobalKey(); // ActiveOrdersCounter (courier)
  final _segmentedKey = GlobalKey(); // HomeSegmentedFilter (courier active)
  final _statusFilterKey = GlobalKey(); // HomeStatusFilter (shop / «Мои»)
  final _ordersKey = GlobalKey(); // лента заказов

  @override
  void initState() {
    super.initState();
    initController();
    startTourIfNeeded(
      screenKey: TourKeys.home,
      targetsBuilder: _buildTourTargets,
    );
  }

  List<TargetFocus> _buildTourTargets() {
    final auth = context.read<AuthProvider>();
    final words = context.read<LanguageProvider>().words;

    if (auth.shouldSkipTour) return const [];

    final isCourier = auth.isCourier;
    final isShop = auth.isShop;
    final isActive = auth.isActive;
    final showsStatusFilter =
        (isShop && isActive) || selectedFilterIndex == 1;

    // Спецификации — потом конвертируем с isLast на последнем элементе.
    final specs =
        <(GlobalKey, String, String, ContentAlign, CustomTargetContentPosition?)>[
      (
        _logoKey,
        isCourier
            ? words.tourHomeWelcomeCourierTitle
            : words.tourHomeWelcomeShopTitle,
        isCourier
            ? words.tourHomeWelcomeCourierBody
            : words.tourHomeWelcomeShopBody,
        ContentAlign.bottom,
        null,
      ),
      if (isCourier && isActive)
        (
          _activeCounterKey,
          words.tourHomeActiveCounterTitle,
          words.tourHomeActiveCounterBody,
          ContentAlign.bottom,
          null,
        ),
      if (isCourier && isActive)
        (
          _segmentedKey,
          words.tourHomeSegmentedTitle,
          words.tourHomeSegmentedBody,
          ContentAlign.bottom,
          null,
        ),
      if (showsStatusFilter)
        (
          _statusFilterKey,
          words.tourHomeStatusFilterTitle,
          words.tourHomeStatusFilterBody,
          ContentAlign.bottom,
          null,
        ),
      (
        _ordersKey,
        isCourier
            ? words.tourHomeOrdersCourierTitle
            : words.tourHomeOrdersShopTitle,
        isCourier
            ? words.tourHomeOrdersCourierBody
            : words.tourHomeOrdersShopBody,
        ContentAlign.top,
        // Лента занимает почти весь экран — прибиваем карточку к низу
        // над навбаром, иначе автопозиционирование уедет за пределы.
        CustomTargetContentPosition(bottom: 110),
      ),
    ];

    return [
      for (var i = 0; i < specs.length; i++)
        TourTarget.build(
          key: specs[i].$1,
          title: specs[i].$2,
          body: specs[i].$3,
          align: specs[i].$4,
          customPosition: specs[i].$5,
          isLast: i == specs.length - 1,
        ),
    ];
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

    // AuthProvider теперь нормализует role/status и предоставляет предикаты.
    final bool isActive = authProv.isActive;
    final bool isShop = authProv.isShop;
    final bool isCourier = authProv.isCourier;
    final bool isBanned = authProv.isBanned;
    final bool isPending = authProv.isPending && (isCourier || isShop);
    final bool isRejected = authProv.isRejected && (isCourier || isShop);
    final bool needsRoleSelection = authProv.needsRoleSelection;

    final filteredOrders = applyFilters(orders);

    final c = AppColors.of(context);

    if (isCourier && levelProvider.pendingLevelUp != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showLevelUp(context, levelProvider);
      });
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        centerTitle: false,
        title: KeyedSubtree(
          key: _logoKey,
          child: HomeLogoRow(
            authProv: authProv,
            realtimeService: realtimeService,
            onRefresh: handleRefresh,
            levelProvider: levelProvider,
          ),
        ),
        actions: [
          if (isCourier)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: KeyedSubtree(
                key: _activeCounterKey,
                child: ActiveOrdersCounter(current: activeOrdersCount, max: 3),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: c.border),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeNetworkBanner(isConnected: realtimeService.isConnected),
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

          if ((isCourier) && isActive)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: KeyedSubtree(
                key: _segmentedKey,
                child: HomeSegmentedFilter(
                  selectedIndex: selectedFilterIndex,
                  onChanged: (i) {
                    if (selectedFilterIndex == i) return;
                    changeFilterIndex(i);
                  },
                  filterActiveCount: filters.activeCount,
                  onFilterTap: showFilterModal,
                  words: words,
                  showFilter: isCourier,
                ),
              ),
            ),

          if (isBanned || isPending || isRejected)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _buildStatusBanner(
                isBanned: isBanned,
                isRejected: isRejected,
                words: words,
                c: c,
              ),
            ),

          if (isShop && isActive || selectedFilterIndex == 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 0, 0),
              child: KeyedSubtree(
                key: _statusFilterKey,
                child: HomeStatusFilter(
                  selectedStatus: selectedStatus,
                  onChanged: (v) => setState(() => selectedStatus = v),
                  counts: {
                    for (final f in getStatusFilters(words))
                      f.value: orders
                          .where(
                            (o) =>
                                f.value == null || o['order_status'] == f.value,
                          )
                          .length,
                  },
                ),
              ),
            ),

          Expanded(
            child: RefreshIndicator(
              key: _ordersKey,
              color: c.ink,
              backgroundColor: c.surface,
              onRefresh: handleRefresh,
              child: HomeOrdersList(
                orders: filteredOrders,
                isLoading: ordersLoading,
                isReloading: ordersReloading,
                hasError: ordersError,
                isShop: isShop,
                loadingMore: loadingMore,
                hasMore: hasMore,
                scrollController: scrollController,
                authProv: authProv,
                words: words,
                onRefresh: handleRefresh,
                swipeEnabled:
                    (isCourier && isActive) || (isShop && isActive),
                // Courier: бинарный Все ↔ Мои
                selectedFilterIndex: selectedFilterIndex,
                onSwipe: isCourier && isActive
                    ? (i) {
                        if (selectedFilterIndex == i) return;
                        changeFilterIndex(i);
                      }
                    : null,
                // Shop: свайп по статусам
                swipeStatuses: isShop && isActive
                    ? [
                        for (final f in getStatusFilters(words)) f.value,
                      ]
                    : null,
                selectedStatus: selectedStatus,
                onStatusSwipe: isShop && isActive
                    ? (v) => setState(() => selectedStatus = v)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner({
    required bool isBanned,
    required bool isRejected,
    required AppLocalizations words,
    required AppColors c,
  }) {
    // Приоритет: banned > rejected > pending.
    final Color color;
    final Color bgColor;
    final IconData icon;
    final String text;
    final String? subtext;
    final VoidCallback? onTap;

    if (isBanned) {
      color = c.errorMuted;
      bgColor = c.errorTint;
      icon = Icons.block_rounded;
      text = words.accountBanned;
      subtext = null;
      onTap = null;
    } else if (isRejected) {
      // Rejected — error-палитра как у banned, НО с подсказкой и тапом.
      color = c.errorMuted;
      bgColor = c.errorTint;
      icon = Icons.edit_note_rounded;
      text = words.accountRejected;
      subtext = words.accountRejectedTap;
      onTap = () => Navigator.pushNamed(context, '/reg-fix')
          .then((_) => handleRefresh());
    } else {
      color = c.amber;
      bgColor = c.amberTint;
      icon = Icons.access_time_rounded;
      text = words.accountPending;
      subtext = null;
      onTap = null;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text,
                    style: AppText.semiBold(fontSize: 13, color: color),
                  ),
                  if (subtext != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtext,
                      style: AppText.regular(
                              fontSize: 11.5, color: color.withValues(alpha: 0.85))
                          .copyWith(height: 1.3),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: color, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}
