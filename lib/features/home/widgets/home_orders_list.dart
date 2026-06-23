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

class HomeOrdersList extends StatefulWidget {
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
  State<HomeOrdersList> createState() => _HomeOrdersListState();
}

class _HomeOrdersListState extends State<HomeOrdersList> {
  /// Точка начала текущего жеста — нужна чтобы считать суммарный сдвиг
  /// в `onPointerUp` (для определения направления свайпа).
  Offset? _pointerStart;

  /// Состояния жеста:
  ///   - `null` — палец оторван или ещё не определились
  ///   - `false` — определили: жест вертикальный, refresh может работать
  ///   - `true`  — определили: жест горизонтальный, refresh заглушаем
  ///
  /// Пока `null` (палец на экране, направление не определено) —
  /// **всё равно** глотаем ScrollNotification. Это критично: иначе
  /// RefreshIndicator успевает активироваться на первых 1-2 пикселях
  /// вертикального движения горизонтального свайпа.
  bool? _direction;

  /// Минимальное общее перемещение (px) чтобы зафиксировать направление.
  /// Берём малое 4 — почти моментально, но защищает от случайного
  /// дёргания пальцем без явного направления.
  static const double _dirCommitDistance = 4;

  /// Минимальный сдвиг по X в `onPointerUp` чтобы триггернуть swipe-action.
  /// Стандарт Material — 60-80 px.
  static const double _hSwipeThreshold = 80;

  void _onPointerDown(PointerDownEvent event) {
    _pointerStart = event.position;
    _direction = null; // пока неизвестно
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_pointerStart == null || _direction != null) return;
    final dx = (event.position.dx - _pointerStart!.dx).abs();
    final dy = (event.position.dy - _pointerStart!.dy).abs();
    // Фиксируем направление как только перемещение стало заметным.
    // Доминирующая ось решает: горизонтально или вертикально.
    if (dx + dy >= _dirCommitDistance) {
      _direction = dx > dy; // true = horizontal, false = vertical
      // setState НЕ нужен: NotificationListener.onNotification читает
      // `_direction` на каждое уведомление в реальном времени.
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    final start = _pointerStart;
    final wasHorizontal = _direction == true;
    _pointerStart = null;
    _direction = null;
    if (start == null || !wasHorizontal) return;
    final dx = event.position.dx - start.dx;
    if (dx.abs() < _hSwipeThreshold) return;
    _handleHorizontalSwipe(dx < 0);
  }

  void _onPointerCancel(PointerCancelEvent _) {
    _pointerStart = null;
    _direction = null;
  }

  /// `forward = true` — пользователь свайпнул влево (→ следующий пункт).
  /// `forward = false` — свайпнул вправо (← предыдущий).
  void _handleHorizontalSwipe(bool forward) {
    // ── Status mode (магазин): свайп по списку статусов ────────────────
    if (widget.swipeStatuses != null && widget.onStatusSwipe != null) {
      final list = widget.swipeStatuses!;
      final idx = list.indexOf(widget.selectedStatus);
      if (idx < 0) return;
      if (forward && idx < list.length - 1) {
        widget.onStatusSwipe!(list[idx + 1]);
      } else if (!forward && idx > 0) {
        widget.onStatusSwipe!(list[idx - 1]);
      } else if (!forward &&
          idx == 0 &&
          widget.onSwipe != null &&
          widget.selectedFilterIndex == 1) {
        // Курьер: на первом статусе свайп вправо возвращает на вкладку «Все».
        widget.onSwipe!(0);
      }
      return;
    }
    // ── Index mode (курьер): бинарный Все ↔ Мои ──────────────────────
    if (widget.onSwipe != null) {
      if (forward && widget.selectedFilterIndex == 0) {
        widget.onSwipe!(1);
      } else if (!forward && widget.selectedFilterIndex == 1) {
        widget.onSwipe!(0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);

    // Если свайп выключен — content как есть (client role, нет табов).
    if (!widget.swipeEnabled) return content;

    final hasItems = widget.orders.isNotEmpty &&
        !widget.isLoading &&
        !widget.isReloading &&
        !widget.hasError;

    // ──────────────────────────────────────────────────────────────────
    // Empty / loading / error: оборачиваем ТОЛЬКО Listener'ом, БЕЗ
    // NotificationListener'а.
    //
    // Почему: при пустом списке нет горизонтально/вертикально-конкурирующего
    // скролла — внутри HomeEmptyState (или CircularProgressIndicator) сам
    // ListView вертикальный, а горизонтальный drag не порождает scroll-
    // notifications. Значит блокировать их незачем.
    //
    // А вот NotificationListener в empty-кейсе ЛОМАЛ pull-to-refresh: на
    // первых пикселях вертикального drag'а `_direction == null`, он
    // глотал ScrollStartNotification → RefreshIndicator никогда не видел
    // начало overscroll'а → refresh не активировался.
    //
    // Translucent Listener видит pointer-events в пустых областях и
    // вызывает onSwipe — ровно то что нужно для свайпа между табами.
    if (!hasItems) {
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: content,
      );
    }

    // ──────────────────────────────────────────────────────────────────
    // Non-empty: Listener + NotificationListener полный arbitration.
    // Тут уже есть карточки и реальный вертикальный скролл, который
    // может стартануть параллельно с горизонтальным жестом — поэтому
    // нужно глотать scroll-notifications до момента определения
    // направления, чтобы RefreshIndicator не «дёргался» при свайпе.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: NotificationListener<ScrollNotification>(
        // **Глотаем** ScrollNotification (return true → не пропускаем
        // выше к RefreshIndicator):
        //   1. Пока палец на экране и направление НЕ определено
        //      (`_direction == null` && `_pointerStart != null`).
        //      Это критично: иначе на первые 1-2 пикселя вертикального
        //      движения горизонтального свайпа refresh успевает
        //      проинициализироваться — и появляется «дёрг».
        //   2. Когда зафиксировали горизонтальное направление
        //      (`_direction == true`).
        //
        // Пропускаем (return false → notification идёт дальше):
        //   3. Когда зафиксировано вертикальное (`_direction == false`).
        //      RefreshIndicator работает как обычно.
        //   4. Когда палец не на экране (свободный inertia-scroll).
        onNotification: (_) {
          if (_pointerStart != null && _direction == null) return true;
          if (_direction == true) return true;
          return false;
        },
        child: content,
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    // Локальные алиасы — чтобы не таскать `widget.` через весь метод,
    // после рефакторинга в StatefulWidget. Это просто чтение полей.
    final isReloading = widget.isReloading;
    final isLoading = widget.isLoading;
    final hasError = widget.hasError;
    final words = widget.words;
    final orders = widget.orders;
    final isShop = widget.isShop;
    final scrollController = widget.scrollController;
    final loadingMore = widget.loadingMore;
    final hasMore = widget.hasMore;
    final authProv = widget.authProv;
    final onRefresh = widget.onRefresh;

    // Tab-switch shimmer — keeps old content feeling alive.
    if (isReloading) return const _ShimmerList();

    // Initial load — shimmer skeleton тоже. Раньше тут был
    // CircularProgressIndicator, что давало ощущение «приложение
    // подвисло». Skeleton намекает на структуру будущего списка
    // и воспринимается как «уже почти готово».
    if (isLoading) return const _ShimmerList();
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
          // RepaintBoundary — каждая карточка получает свой raster-слой,
          // изменение одной не репейнтит соседей.
          return RepaintBoundary(
            child: OrderCard(
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
            ),
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
