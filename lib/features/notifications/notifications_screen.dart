import 'dart:async';

import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/core/tour/app_tour_mixin.dart';
import 'package:bagla/core/tour/tour_keys.dart';
import 'package:bagla/core/tour/tour_target.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/features/notifications/notification_dto.dart';
import 'package:bagla/features/notifications/notification_service.dart';
import 'package:bagla/features/notifications/widgets/notification_helpers.dart';
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
  final _markAllKey = GlobalKey();
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

  // ── Mark-all-read undo state ───────────────────────────────────────────
  // Lifted to fields, чтобы dispose() мог корректно завершить операцию
  // даже если пользователь успел разлогиниться/уйти с экрана.
  Timer? _markAllTimer;
  Set<String>? _markAllPendingIds;
  bool _markAllUndone = false;

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
    );

    _scrollCtrl.addListener(_onScroll);

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Кэшируем messenger для dispose().
    _messenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    // Если был активный mark-all undo-window и пользователь не отменил —
    // принудительно гасим SnackBar и сразу шлём PATCH (fire-and-forget).
    _markAllTimer?.cancel();
    final pending = _markAllPendingIds;
    if (pending != null && !_markAllUndone && _userId.isNotEmpty) {
      // Fire-and-forget — на экране нас уже нет.
      _service.markAllAsRead(_userId);
    }
    _messenger?.clearSnackBars();

    _scrollCtrl
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
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
      setState(() {
        _items = data
            .whereType<Map>()
            .map((m) => NotificationDto.fromMap(Map<String, dynamic>.from(m)))
            .map(
              (n) => _pendingRead.contains(n.id) ? n.copyWith(isRead: true) : n,
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
      setState(() {
        for (final raw in more.whereType<Map>()) {
          final dto = NotificationDto.fromMap(Map<String, dynamic>.from(raw));
          if (_items.any((x) => x.id == dto.id)) continue;
          _items.add(_pendingRead.contains(dto.id) ? dto.copyWith(isRead: true) : dto);
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

  /// Mark-all с оптимистичным апдейтом + toast «Отменить» (5 сек).
  Future<void> _markAllRead() async {
    final words = context.read<LanguageProvider>().words;

    // Снимок «было прочитано» — для undo.
    final snapshot = {for (final n in _items) n.id: n.isRead};
    final unreadIds = _items
        .where((n) => !n.isRead)
        .map((n) => n.id)
        .toSet();
    if (unreadIds.isEmpty) return;

    _pendingRead.addAll(unreadIds);
    setState(() {
      _items = _items.map((n) => n.copyWith(isRead: true)).toList();
    });

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final c = AppColors.of(context);
    const duration = Duration(seconds: 5);

    // Сбрасываем и лифтим в поля — чтобы dispose() мог корректно отработать.
    _markAllTimer?.cancel();
    _markAllUndone = false;
    _markAllPendingIds = unreadIds;

    final controller = messenger.showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MainShell.bottomReserve(context),
        ),
        backgroundColor: c.ink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Row(
          children: [
            // Круглый таймер обратного отсчёта слева (5 сек, линейный спад).
            // Когда дойдёт до 0 — SnackBar закроется и PATCH уйдёт на сервер.
            SizedBox(
              width: 18,
              height: 18,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 1.0, end: 0.0),
                duration: duration,
                curve: Curves.linear,
                builder: (_, value, _) => CircularProgressIndicator(
                  value: value,
                  strokeWidth: 2,
                  color: c.amber,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                words.notifMarkAllToast.replaceAll(
                  '{n}',
                  '${unreadIds.length}',
                ),
                style: AppText.medium(fontSize: 13, color: Colors.white),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: words.notifUndo,
          textColor: c.amber,
          onPressed: () {
            _markAllUndone = true;
            _markAllTimer?.cancel();
            _markAllPendingIds = null;
            _pendingRead.removeAll(unreadIds);
            if (!mounted) return;
            setState(() {
              _items = _items
                  .map(
                    (n) => snapshot.containsKey(n.id)
                        ? n.copyWith(isRead: snapshot[n.id])
                        : n,
                  )
                  .toList();
            });
          },
        ),
      ),
    );

    // Ровно через 5 секунд:
    //  – принудительно закрываем SnackBar (на случай если визуально завис),
    //  – если не было Undo — отправляем PATCH на сервер.
    _markAllTimer = Timer(duration, () async {
      controller.close();
      if (_markAllUndone) return;
      try {
        await _service.markAllAsRead(_userId);
      } finally {
        _pendingRead.removeAll(unreadIds);
        if (identical(_markAllPendingIds, unreadIds)) {
          _markAllPendingIds = null;
        }
      }
    });
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
        key: _titleKey,
        title: words.tourNotifTitleTitle,
        body: words.tourNotifTitleBody,
        align: ContentAlign.bottom,
      ),
      TourTarget.build(
        key: _markAllKey,
        title: words.tourNotifMarkAllTitle,
        body: words.tourNotifMarkAllBody,
        align: ContentAlign.bottom,
      ),
      TourTarget.build(
        key: _listKey,
        title: words.tourNotifListTitle,
        body: words.tourNotifListBody,
        isLast: true,
        align: ContentAlign.top,
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
        automaticallyImplyLeading: false,
        title: KeyedSubtree(
          key: _titleKey,
          child: Text(
            words.notifTitle,
            style: AppText.serif(fontSize: 20, letterSpacing: -0.3),
          ),
        ),
        actions: [
          KeyedSubtree(
            key: _markAllKey,
            child: _MarkAllButton(
              onTap: _markAllRead,
              label: words.notifMarkAll,
            ),
          ),
        ],
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
      return Center(
        child: CircularProgressIndicator(color: c.ink, strokeWidth: 2),
      );
    }
    if (_hasError && _items.isEmpty) return _buildError(words);
    if (_items.isEmpty) return _buildEmpty(words);

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
        onTap: () {
          if (!n.isRead) _markRead(n.id);
        },
      );

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
                color: c.errorTint,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: c.errorMuted.withValues(alpha: 0.25),
                ),
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: 28,
                color: c.errorMuted,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              words.notifLoadError,
              textAlign: TextAlign.center,
              style: AppText.semiBold(fontSize: 15, color: c.ink),
            ),
            const SizedBox(height: 14),
            _RetryButton(
              label: words.notifRetry,
              onPressed: () => _loadNotifications(),
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
// Mark-all button
// ═════════════════════════════════════════════════════════════════════════════

class _MarkAllButton extends StatefulWidget {
  final VoidCallback onTap;
  final String label;
  const _MarkAllButton({required this.onTap, required this.label});

  @override
  State<_MarkAllButton> createState() => _MarkAllButtonState();
}

class _MarkAllButtonState extends State<_MarkAllButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: Builder(
        builder: (context) {
          final c = AppColors.of(context);
          return AnimatedScale(
            scale: _pressed ? 0.95 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding:
                  const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: c.emeraldTint,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.ink.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.done_all_rounded, color: c.ink, size: 13),
                  const SizedBox(width: 5),
                  Text(
                    widget.label,
                    style: AppText.semiBold(fontSize: 12, color: c.ink),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Retry button (error state)
// ═════════════════════════════════════════════════════════════════════════════

class _RetryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _RetryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: c.ink,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.refresh_rounded, color: Colors.white, size: 15),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppText.semiBold(fontSize: 13, color: Colors.white),
              ),
            ],
          ),
        ),
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
                    notifTypeIcon(n.type),
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
