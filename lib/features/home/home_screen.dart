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
  final _logoKey = GlobalKey();
  final _ordersKey = GlobalKey();

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
    final lang = context.read<LanguageProvider>();
    return [
      TourTarget.build(
        key: _logoKey,
        titleRu: 'Главная страница',
        titleTk: 'Baş sahypa',
        bodyRu:
            'Здесь отображаются все ваши заказы. Потяните вниз чтобы обновить список.',
        bodyTk:
            'Bu ýerde ähli sargytlaryňyz görkezilýär. Sanawyny täzelemek üçin aşak çekiň.',
        isRu: lang.isRu,
        align: ContentAlign.bottom,
      ),
      // _ordersKey wraps the full-screen RefreshIndicator, so auto-calculated
      // ContentAlign.top would land off-screen. Pin the card above the nav bar.
      TourTarget.build(
        key: _ordersKey,
        titleRu: 'Список заказов',
        titleTk: 'Sargytlar sanawy',
        bodyRu: 'Нажмите на заказ чтобы увидеть детали и принять его.',
        bodyTk: 'Jikme-jikleri görmek we kabul etmek üçin sargyta basyň.',
        isRu: lang.isRu,
        customPosition: CustomTargetContentPosition(bottom: 110),
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
              child: ActiveOrdersCounter(current: activeOrdersCount, max: 3),
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

          if (isBanned || isPending)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _buildStatusBanner(isBanned, words, c),
            ),

          if (isShop && isActive || selectedFilterIndex == 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 0, 0),
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

          Expanded(
            child: RefreshIndicator(
              key: _ordersKey,
              color: c.ink,
              backgroundColor: c.surface,
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
                swipeEnabled: isCourier && isActive,
                selectedFilterIndex: selectedFilterIndex,
                onSwipe: isCourier && isActive
                    ? (i) {
                        if (selectedFilterIndex == i) return;
                        changeFilterIndex(i);
                      }
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(
    bool isBanned,
    AppLocalizations words,
    AppColors c,
  ) {
    final color = isBanned ? c.errorMuted : c.amber;
    final bgColor = isBanned ? c.errorTint : c.amberTint;
    final icon = isBanned ? Icons.block_rounded : Icons.access_time_rounded;
    final text = isBanned ? words.accountBanned : words.accountPending;

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
