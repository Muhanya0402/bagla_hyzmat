import 'package:animations/animations.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/features/home/widgets/home_widgets.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/features/home/widgets/role_picker_modal.dart';
import 'package:flutter/material.dart';
import 'package:bagla/core/app_text_styles.dart';

import 'package:bagla/features/orders/order_card.dart';
import 'package:bagla/features/orders/order_detail_screen.dart';
import 'package:bagla/l10n/app_localizations.dart';

class HomeOrdersList extends StatelessWidget {
  final List<dynamic> orders;
  final bool isLoading;
  final bool isReloading; // true while switching tabs — shows shimmer
  final bool hasError;
  final bool isShop;
  final bool loadingMore;
  final bool hasMore;
  final ScrollController scrollController;
  final AuthProvider authProv;
  final AppLocalizations words;
  final VoidCallback onRefresh;
  final bool swipeEnabled;

  // ── Courier mode: бинарный свайп между Все/Мои ──────────────────────────
  final int selectedFilterIndex;
  final ValueChanged<int>? onSwipe;

  // ── Shop mode: свайп по списку статусов ─────────────────────────────────
  /// Упорядоченный список значений статус-фильтра (включая `null` для «Все»).
  /// Если задан вместе с [onStatusSwipe] — активен status-mode свайпа.
  final List<String?>? swipeStatuses;
  final String? selectedStatus;
  final ValueChanged<String?>? onStatusSwipe;

  const HomeOrdersList({
    super.key,
    required this.orders,
    required this.isLoading,
    required this.hasError,
    required this.isShop,
    required this.loadingMore,
    required this.hasMore,
    required this.scrollController,
    required this.authProv,
    required this.words,
    required this.onRefresh,
    this.isReloading = false,
    this.swipeEnabled = false,
    this.selectedFilterIndex = 0,
    this.onSwipe,
    this.swipeStatuses,
    this.selectedStatus,
    this.onStatusSwipe,
  });

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);
    if (!swipeEnabled) return content;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v.abs() < 300) return;

        // ── Status mode (магазин): свайп по списку статусов ────────────
        if (swipeStatuses != null && onStatusSwipe != null) {
          final list = swipeStatuses!;
          final idx = list.indexOf(selectedStatus);
          if (idx < 0) return;
          if (v < 0 && idx < list.length - 1) {
            onStatusSwipe!(list[idx + 1]);
          } else if (v > 0 && idx > 0) {
            onStatusSwipe!(list[idx - 1]);
          }
          return;
        }

        // ── Index mode (курьер): бинарный Все ↔ Мои ────────────────────
        if (onSwipe != null) {
          if (v < 0 && selectedFilterIndex == 0) {
            onSwipe!(1);
          } else if (v > 0 && selectedFilterIndex == 1) {
            onSwipe!(0);
          }
        }
      },
      child: content,
    );
  }

  Widget _buildContent(BuildContext context) {
    // Tab-switch shimmer — keeps old content feeling alive.
    if (isReloading) return const _ShimmerList();

    // Initial load — full-screen spinner.
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: AppColors.of(context).ink,
          strokeWidth: 2,
        ),
      );
    }
    if (hasError) {
      return HomeEmptyState(
        icon: Icons.wifi_off_rounded,
        text: words.ordersLoadError,
      );
    }
    if (orders.isEmpty) {
      return HomeEmptyState(
        icon: Icons.inbox_rounded,
        text: isShop ? words.shopEmptyList : words.emptyList,
      );
    }

    return ListView.builder(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      itemCount: orders.length + 1,
      addAutomaticKeepAlives: false,
      itemBuilder: (context, index) {
        if (index == orders.length) {
          if (loadingMore) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.of(context).ink,
                  strokeWidth: 2,
                ),
              ),
            );
          }
          if (!hasMore && orders.isNotEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  words.ordersAllLoaded,
                  style: AppText.regular(
                    fontSize: 12,
                    color: AppColors.of(context).inkSoft,
                  ),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }

        if (authProv.role == 'client') {
          return OrderCard(
            order: orders[index],
            role: 'courier',
            currentUserId: authProv.userId,
            userPhone: authProv.phone,
            onUpdate: onRefresh,
            onTap: () => showModalBottomSheet(
              context: context,
              useRootNavigator: true,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => RolePickerEmbedded(
                onClose: () =>
                    Navigator.of(context, rootNavigator: true).pop(),
              ),
            ).then((_) => onRefresh()),
          );
        }

        final c     = AppColors.of(context);
        final role  = isShop ? 'shop' : 'courier';
        final order = orders[index];

        return RepaintBoundary(
          child: OpenContainer<void>(
            tappable: false,
            transitionDuration: const Duration(milliseconds: 340),
            transitionType: ContainerTransitionType.fadeThrough,
            closedColor: c.surface,
            openColor: c.bg,
            middleColor: c.bg,
            closedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            openShape: const RoundedRectangleBorder(),
            closedElevation: 0,
            openElevation: 0,
            onClosed: (_) => onRefresh(),
            closedBuilder: (_, openContainer) => OrderCard(
              order: order,
              role: role,
              currentUserId: authProv.userId,
              userPhone: authProv.phone,
              onUpdate: onRefresh,
              onTap: openContainer,
            ),
            openBuilder: (_, _) => OrderDetailScreen(
              order: order,
              role: role,
              currentUserId: authProv.userId,
              onUpdate: onRefresh,
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer skeleton shown while switching tabs
// ─────────────────────────────────────────────────────────────────────────────

class _ShimmerList extends StatefulWidget {
  const _ShimmerList();

  @override
  State<_ShimmerList> createState() => _ShimmerListState();
}

class _ShimmerListState extends State<_ShimmerList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    // Base skeleton colour and the brighter highlight that sweeps across.
    final base      = c.borderSoft;
    final highlight = Color.lerp(c.borderSoft, c.surface, 0.78)!;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value;
        // Gradient begins off-screen left and sweeps to off-screen right.
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              begin: Alignment(-1.8 + 3.6 * t, 0),
              end:   Alignment(-0.8 + 3.6 * t, 0),
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
              tileMode: TileMode.clamp,
            ).createShader(bounds);
          },
          child: child,
        );
      },
      // The skeleton list is the static child — rebuilt once, animated by shader.
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, _) => _ShimmerCard(c: c),
      ),
    );
  }
}

// Skeleton card mimicking the OrderCard shape.
class _ShimmerCard extends StatelessWidget {
  final AppColors c;
  const _ShimmerCard({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: c.borderSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: transport icon + order id + status badge
          Row(
            children: [
              _bone(32, 32, radius: 10),
              const SizedBox(width: 8),
              _bone(88, 12, radius: 6),
              const Spacer(),
              _bone(68, 22, radius: 10),
            ],
          ),
          const SizedBox(height: 10),
          // Row 2: address from
          _bone(double.infinity, 10, radius: 5),
          const SizedBox(height: 7),
          // Row 3: address to
          _bone(150, 10, radius: 5),
        ],
      ),
    );
  }

  // A single placeholder block (filled white so ShaderMask paints over it).
  Widget _bone(double w, double h, {required double radius}) => Container(
    width: w == double.infinity ? null : w,
    height: h,
    decoration: BoxDecoration(
      // White so blendMode.srcIn exposes the shimmer gradient here.
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}
