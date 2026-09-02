import 'dart:async';

import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/core/widgets/shimmer.dart';
import 'package:bagla/core/tour/app_tour_mixin.dart';
import 'package:bagla/core/tour/tour_keys.dart';
import 'package:bagla/core/tour/tour_target.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/features/notifications/notification_dto.dart';
import 'package:bagla/features/notifications/notification_service.dart';
import 'package:bagla/features/notifications/widgets/notification_helpers.dart';
import 'package:bagla/features/orders/courier_report_service.dart';
import 'package:bagla/features/orders/order_detail_screen.dart';
import 'package:bagla/features/orders/order_service.dart';
import 'package:bagla/features/shell/main_shell.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Screen
// ═════════════════════════════════════════════════════════════════════════════

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => NotificationsScreenState();
}

class NotificationsScreenState extends State<NotificationsScreen>
    with AppTourMixin<NotificationsScreen> {
  static const int _pageSize = 30;

  final NotificationService _service = NotificationService();
  final _scrollCtrl = ScrollController();

  // Tour anchors.
  final _titleKey = GlobalKey();
  final _listKey = GlobalKey();

  List<NotificationDto> _items = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  late String _userId;

  // IDs optimistically marked as read locally but not yet confirmed by server.
  // Prevents pull-to-refresh from reverting them before the PATCH resolves.
  final Set<String> _pendingRead = {};

  // ScaffoldMessenger кэшируется через didChangeDependencies, потому что
  // в dispose() обращаться к context уже нельзя.
  ScaffoldMessengerState? _messenger;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _userId = auth.userId;

    startTourIfNeeded(
      screenKey: TourKeys.notifications,
      targetsBuilder: _buildTourTargets,
      shouldSkip: () => context.read<AuthProvider>().shouldSkipTour,
    );

    _scrollCtrl.addListener(_onScroll);
    // Подписка на глобальный сигнал «прочитанность изменилась» — чтобы
    // после «Прочитать все» в unread-модалке (с home) список здесь
    // обновился сам, без pull-to-refresh.
    NotificationService.readStateRevision.addListener(_onReadStateChanged);

    if (_userId.isNotEmpty) {
      _loadNotifications();
    } else {
      void listener() {
        final id = auth.userId;
        if (id.isNotEmpty && _userId.isEmpty) {
          _userId = id;
          _loadNotifications();
          auth.removeListener(listener);
        }
      }

      auth.addListener(listener);
    }
  }

  /// Сработал глобальный сигнал прочитанности (markAsRead/markAllAsRead из
  /// любого места — модалка с home, пуш и т.д.). Тихо перезагружаем список.
  void _onReadStateChanged() {
    if (!mounted || _userId.isEmpty) return;
    _loadNotifications(silent: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Кэшируем messenger для dispose().
    _messenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    _messenger?.clearSnackBars();
    NotificationService.readStateRevision.removeListener(_onReadStateChanged);

    _scrollCtrl
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// Авто-пометка всех уведомлений прочитанными при открытии экрана
  /// (заменяет кнопку «Прочитать все»). Тихо, без снэкбара/undo.
  /// Вызывается из MainShell при переключении на таб уведомлений.
  void markAllReadOnOpen() {
    if (_userId.isEmpty) return;
    if (_items.any((n) => !n.isRead)) {
      setState(() {
        _items =
            _items.map((n) => n.isRead ? n : n.copyWith(isRead: true)).toList();
      });
    }
    // markAllAsRead сам обновит локальный кэш read-id, сервер и revision
    // (внутри берёт реальный список непрочитанных — повторный вызов безопасен).
    // Ошибку здесь глушим: экран открывается молча, показывать пользователю
    // нечего — при следующем открытии пометка просто повторится.
    _service.markAllAsRead(_userId).catchError((_) {});
  }

  // ── Data ────────────────────────────────────────────────────────────────

  Future<void> _loadNotifications({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final data = await _service.getNotifications(
        _userId,
        limit: _pageSize,
        offset: 0,
      );
      if (!mounted) return;
      // Глобальный кэш id'шек, помеченных как прочитанные клиентом
      // (включая случай тапа на push до cold-start этого экрана).
      final globalRead = NotificationService.locallyReadIds;
      setState(() {
        _items = data
            .whereType<Map>()
            .map((m) => NotificationDto.fromMap(Map<String, dynamic>.from(m)))
            .map(
              (n) => (_pendingRead.contains(n.id) || globalRead.contains(n.id))
                  ? n.copyWith(isRead: true)
                  : n,
            )
            .toList();
        _isLoading = false;
        _hasError = false;
        _hasMore = data.length >= _pageSize;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _isLoading || _hasError) return;
    setState(() => _loadingMore = true);
    try {
      final more = await _service.getNotifications(
        _userId,
        limit: _pageSize,
        offset: _items.length,
      );
      if (!mounted) return;
      final globalRead = NotificationService.locallyReadIds;
      setState(() {
        for (final raw in more.whereType<Map>()) {
          final dto = NotificationDto.fromMap(Map<String, dynamic>.from(raw));
          if (_items.any((x) => x.id == dto.id)) continue;
          _items.add(
            (_pendingRead.contains(dto.id) || globalRead.contains(dto.id))
                ? dto.copyWith(isRead: true)
                : dto,
          );
        }
        _hasMore = more.length >= _pageSize;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _refresh() => _loadNotifications(silent: true);

  Future<void> _markRead(String id) async {
    _pendingRead.add(id);
    setState(() {
      _items = _items
          .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
          .toList();
    });
    await _service.markAsRead(id);
    _pendingRead.remove(id);
  }

  void refresh() => _loadNotifications(silent: true);

  // ── Group into today / yesterday / earlier ──────────────────────────────

  ({List<NotificationDto> today, List<NotificationDto> yesterday, List<NotificationDto> earlier})
      _groupItems() {
    final today = <NotificationDto>[];
    final yesterday = <NotificationDto>[];
    final earlier = <NotificationDto>[];
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));

    for (final n in _items) {
      final dt = n.createdAt;
      if (dt == null) {
        earlier.add(n);
      } else if (dt.isAfter(todayStart)) {
        today.add(n);
      } else if (dt.isAfter(yesterdayStart)) {
        yesterday.add(n);
      } else {
        earlier.add(n);
      }
    }
    return (today: today, yesterday: yesterday, earlier: earlier);
  }

  // ── Tour ────────────────────────────────────────────────────────────────

  List<TargetFocus> _buildTourTargets() {
    final words = context.read<LanguageProvider>().words;
    final auth = context.read<AuthProvider>();

    if (auth.shouldSkipTour) return const [];

    return [
      TourTarget.build(
        id: 'notif_0',
        key: _titleKey,
        title: words.tourNotifTitleTitle,
        body: words.tourNotifTitleBody,
        align: ContentAlign.bottom,
      ),
      TourTarget.build(
        id: 'notif_2',
        key: _listKey,
        title: words.tourNotifListTitle,
        body: words.tourNotifListBody,
        isLast: true,
        // Подсветка накрывает ВЕСЬ список, а он начинается сразу под шапкой.
        // При `ContentAlign.top` карточке негде разместиться сверху, и на
        // невысоких экранах она уезжала за край вместе с «Пропустить» и
        // «Продолжить». Прижимаем её к низу экрана — тот же приём, что уже
        // применён на «Обращениях» и «Истории транзакций», где такие же
        // списки на всю высоту.
        customPosition: CustomTargetContentPosition(bottom: 110),
      ),
    ];
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final words = context.watch<LanguageProvider>().words;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        title: KeyedSubtree(
          key: _titleKey,
          child: Text(
            words.notifTitle,
            style: AppText.serif(fontSize: 20, letterSpacing: -0.3),
          ),
        ),
        // Кнопка «Прочитать все» убрана: при открытии экрана все уведомления
        // помечаются прочитанными автоматически (markAllReadOnOpen из MainShell).
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: c.border),
        ),
      ),
      body: _buildBody(words),
    );
  }

  Widget _buildBody(AppLocalizations words) {
    final c = AppColors.of(context);
    if (_isLoading) {
      return const ShimmerListSkeleton(itemHeight: 72);
    }
    // #2-fix: пустое и error-состояния тоже должны тянуться вниз для refresh.
    // Раньше они были не-скроллируемыми Center'ами без RefreshIndicator —
    // pull-to-refresh не работал (особенно заметно у наблюдателя с пустым
    // списком, когда новое уведомление нельзя было подтянуть).
    if (_items.isEmpty) {
      final content = (_hasError) ? _buildError(words) : _buildEmpty(words);
      return RefreshIndicator(
        color: c.ink,
        backgroundColor: c.surface,
        onRefresh: _refresh,
        child: LayoutBuilder(
          builder: (_, constraints) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: constraints.maxHeight, child: content),
            ],
          ),
        ),
      );
    }

    final groups = _groupItems();
    final bottomReserve = MainShell.bottomReserve(context) + 8;

    return RefreshIndicator(
      key: _listKey,
      color: c.ink,
      backgroundColor: c.surface,
      onRefresh: _refresh,
      child: ListView(
        controller: _scrollCtrl,
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottomReserve),
        children: [
          if (groups.today.isNotEmpty) ...[
            _SectionLabel(text: words.notifToday),
            const SizedBox(height: 6),
            ...groups.today.map(_card),
          ],
          if (groups.yesterday.isNotEmpty) ...[
            if (groups.today.isNotEmpty) const SizedBox(height: 6),
            _SectionLabel(text: words.notifYesterday),
            const SizedBox(height: 6),
            ...groups.yesterday.map(_card),
          ],
          if (groups.earlier.isNotEmpty) ...[
            if (groups.today.isNotEmpty || groups.yesterday.isNotEmpty)
              const SizedBox(height: 6),
            _SectionLabel(text: words.notifEarlier),
            const SizedBox(height: 6),
            ...groups.earlier.map(_card),
          ],
          if (_loadingMore)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: c.ink,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else if (!_hasMore && _items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  words.notifAllLoaded,
                  style: AppText.regular(fontSize: 11.5, color: c.inkSoft),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card(NotificationDto n) => _NotifCard(
        key: ValueKey(n.id),
        notif: n,
        onTap: () => _openNotification(n),
      );

  /// Тап по уведомлению: помечаем прочитанным и, если это уведомление о
  /// заказе с известным id — открываем сам заказ (#3), а не остаёмся в
  /// списке уведомлений.
  Future<void> _openNotification(NotificationDto n) async {
    if (!n.isRead) _markRead(n.id);

    if (!notifIsOrder(n.type)) return;
    final orderId = notifOrderId(n.raw);
    if (orderId == null) return;

    final auth = context.read<AuthProvider>();
    final words = context.read<LanguageProvider>().words;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final order = await OrderService().getOrderById(orderId);
    if (!mounted) return;
    if (order == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(words.error, style: AppText.regular(fontSize: 13)),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Уведомление «Новый заказ» приходит всем курьерам, и к моменту тапа
    // заказ мог уже уйти другому. В чужой заказ не пускаем — там видны
    // телефон и адрес клиента.
    if (!OrderService.canOpenOrder(
      order,
      role: auth.role,
      userId: auth.userId,
    )) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            words.orderAlreadyTaken,
            style: AppText.regular(fontSize: 13),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    navigator.push(
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(
          order: order,
          role: auth.role,
          currentUserId: auth.userId,
          onUpdate: refresh,
        ),
      ),
    );
  }

  // ── Empty state ─────────────────────────────────────────────────────────

  Widget _buildEmpty(AppLocalizations words) {
    final c = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: c.border),
              ),
              child: Icon(
                Icons.notification_important_outlined,
                size: 28,
                color: c.inkSoft.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              words.notifEmpty,
              style: AppText.semiBold(fontSize: 15, color: c.ink),
            ),
            const SizedBox(height: 6),
            Text(
              words.notifEmptyDesc,
              textAlign: TextAlign.center,
              style: AppText.regular(fontSize: 13, color: c.inkMuted)
                  .copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error state ─────────────────────────────────────────────────────────

  // Состояние ошибки — единый вид с home_screen (HomeEmptyState):
  // нейтральная иконка wifi_off в рамке + текст, без кнопки «Повторить»
  // (обновление — pull-to-refresh, как на главной).
  Widget _buildError(AppLocalizations words) {
    final c = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: c.bg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: c.border),
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 28,
                color: c.ink.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              words.notifLoadError,
              textAlign: TextAlign.center,
              style: AppText.medium(fontSize: 13, color: c.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Section label
// ═════════════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 2),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 11,
            decoration: BoxDecoration(
              color: c.ink,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            text.toUpperCase(),
            style: AppText.semiBold(fontSize: 10, color: c.inkSoft)
                .copyWith(letterSpacing: 0.8),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Notification card
// ═════════════════════════════════════════════════════════════════════════════

class _NotifCard extends StatefulWidget {
  final NotificationDto notif;
  final VoidCallback onTap;

  const _NotifCard({super.key, required this.notif, required this.onTap});

  @override
  State<_NotifCard> createState() => _NotifCardState();
}

class _NotifCardState extends State<_NotifCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final words = lang.words;
    final c = AppColors.of(context);
    final n = widget.notif;
    final style = notifTypeStyle(n.type, c);

    final String timeStr = notifFormatDate(
      n.raw['date_created']?.toString(),
      words,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: n.isRead ? c.surface : style.icon.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: n.isRead
                  ? c.borderSoft
                  : style.icon.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: n.isRead ? 0 : 3,
                height: 56,
                decoration: BoxDecoration(
                  color: style.icon,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: style.bg,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    notifTypeIcon(n.type, transport: n.transportType),
                    color: style.icon,
                    size: 18,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              n.title(lang.isRu),
                              style: n.isRead
                                  ? AppText.medium(fontSize: 13, color: c.ink)
                                  : AppText.semiBold(
                                      fontSize: 13,
                                      color: c.ink,
                                    ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                timeStr,
                                style: AppText.regular(
                                  fontSize: 11,
                                  color: c.inkSoft,
                                ),
                              ),
                              if (!n.isRead) ...[
                                const SizedBox(width: 6),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: style.icon,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      if (n.body(lang.isRu).isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          n.body(lang.isRu),
                          style: AppText.regular(
                            fontSize: 12,
                            color: c.inkMuted,
                          ).copyWith(height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      // Кнопка модератора: отстранить курьера прямо отсюда,
                      // не заходя в панель. Приходит только тем учёткам, у
                      // которых стоит признак модератора.
                      if (n.type == 'report_alert') ...[
                        const SizedBox(height: 10),
                        _BlockCourierButton(notif: n),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ═════════════════════════════════════════════════════════════════════════════
// Кнопка «Отстранить» в уведомлении модератора
// ═════════════════════════════════════════════════════════════════════════════

/// Отстраняет курьера на срок, который предложил сервер.
///
/// Кого и на сколько — приходит в самом уведомлении, так что модератору не
/// нужно ничего вводить: посмотрел причину и нажал. Право отстранять
/// проверяет сервер, здесь мы лишь передаём, кто нажал.
class _BlockCourierButton extends StatefulWidget {
  final NotificationDto notif;
  const _BlockCourierButton({required this.notif});

  @override
  State<_BlockCourierButton> createState() => _BlockCourierButtonState();
}

class _BlockCourierButtonState extends State<_BlockCourierButton> {
  bool _loading = false;
  bool _done = false;

  String get _courierId =>
      (widget.notif.raw['report_courier_id'] ?? '').toString();

  int get _days {
    final v = widget.notif.raw['report_block_days'];
    return v is int ? v : int.tryParse((v ?? '').toString()) ?? 1;
  }

  Future<void> _confirmAndBlock(AppLocalizations words) async {
    final c = AppColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          words.reportBlockConfirmTitle,
          style: AppText.serif(fontSize: 17, color: c.ink),
        ),
        content: Text(
          words.reportBlockConfirmBody,
          style: AppText.regular(fontSize: 13.5, color: c.inkMuted)
              .copyWith(height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              words.reportBlockConfirmNo,
              style: AppText.medium(fontSize: 14, color: c.inkMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              words.reportBlockConfirmYes,
              style: AppText.semiBold(fontSize: 14, color: c.errorMuted),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    final moderatorId = context.read<AuthProvider>().userId;
    final success = await CourierReportService().blockCourier(
      courierId: _courierId,
      days: _days,
      moderatorId: moderatorId,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _done = success;
    });
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success ? words.reportBlockDone : words.reportBlockFailed,
          style: AppText.regular(
            fontSize: 13,
            color: success ? c.ink : c.errorMuted,
          ),
        ),
        backgroundColor: success ? c.emeraldTint : c.errorTint,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_courierId.isEmpty) return const SizedBox.shrink();
    final c = AppColors.of(context);
    final words = context.watch<LanguageProvider>().words;

    if (_done) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 14, color: c.inkMuted),
          const SizedBox(width: 6),
          Text(
            words.reportBlockDone,
            style: AppText.medium(fontSize: 12, color: c.inkMuted),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: _loading ? null : () => _confirmAndBlock(words),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: c.errorTint,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.errorMuted.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_loading)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: c.errorMuted,
                ),
              )
            else
              Icon(Icons.block_rounded, size: 14, color: c.errorMuted),
            const SizedBox(width: 7),
            Text(
              '${words.reportBlockBtn} · $_days',
              style: AppText.semiBold(fontSize: 12.5, color: c.errorMuted),
            ),
          ],
        ),
      ),
    );
  }
}
