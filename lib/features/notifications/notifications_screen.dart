import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/tour/app_tour_mixin.dart';
import 'package:bagla/core/tour/tour_keys.dart';
import 'package:bagla/core/tour/tour_target.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/features/notifications/notification_service.dart';
import 'package:bagla/features/notifications/widgets/notification_helpers.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

// ─── Type → visual style ───────────────────────────────────────────────────────

({Color bg, Color icon}) _typeStyle(String type, AppColors c) {
  switch (type) {
    case 'daily_bonus':
      return (bg: c.amberTint, icon: c.amber);
    case 'new_order':
    case 'order_status':
      return (bg: c.emeraldTint, icon: c.ink);
    case 'account_status':
      return (bg: c.errorTint, icon: c.errorMuted);
    default:
      return (bg: c.borderSoft, icon: c.inkSoft);
  }
}

// ─── Screen ────────────────────────────────────────────────────────────────────

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => NotificationsScreenState();
}

class NotificationsScreenState extends State<NotificationsScreen>
    with AppTourMixin<NotificationsScreen> {
  final NotificationService _service = NotificationService();

  final _titleKey = GlobalKey();
  final _listKey = GlobalKey();

  List<dynamic> _items = [];
  bool _isLoading = true;
  late String _userId;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _userId = auth.userId;

    startTourIfNeeded(
      screenKey: TourKeys.notifications,
      targetsBuilder: _buildTourTargets,
    );

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

  Future<void> _loadNotifications({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLoading = true);
    final data = await _service.getNotifications(_userId);
    if (!mounted) return;
    setState(() {
      _items = data;
      _isLoading = false;
    });
  }

  Future<void> _refresh() => _loadNotifications(silent: true);

  Future<void> _markAllRead() async {
    await _service.markAllAsRead(_userId);
    if (!mounted) return;
    setState(() {
      _items = _items.map((n) => {...n, 'is_read': true}).toList();
    });
  }

  Future<void> _markRead(String id) async {
    setState(() {
      _items = _items.map((n) {
        if (n['id'].toString() == id) return {...n, 'is_read': true};
        return n;
      }).toList();
    });
    await _service.markAsRead(id);
  }

  void refresh() => _loadNotifications(silent: true);

  // ── Group into today / yesterday / earlier ─────────────────────────────────

  ({List<dynamic> today, List<dynamic> yesterday, List<dynamic> earlier})
  _groupItems() {
    final today = <dynamic>[];
    final yesterday = <dynamic>[];
    final earlier = <dynamic>[];
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));

    for (final n in _items) {
      try {
        final dt = DateTime.parse(
          (n['date_created'] ?? '').toString(),
        ).toLocal();
        if (dt.isAfter(todayStart)) {
          today.add(n);
        } else if (dt.isAfter(yesterdayStart)) {
          yesterday.add(n);
        } else {
          earlier.add(n);
        }
      } catch (_) {
        earlier.add(n);
      }
    }
    return (today: today, yesterday: yesterday, earlier: earlier);
  }

  List<TargetFocus> _buildTourTargets() {
    final lang = context.read<LanguageProvider>();
    return [
      TourTarget.build(
        key: _titleKey,
        titleRu: 'Уведомления',
        titleTk: 'Habarnamalar',
        bodyRu:
            'Здесь появляются все системные уведомления — новые заказы, статусы и бонусы.',
        bodyTk:
            'Bu ýerde ähli ulgam habarlary görkezilýär — täze sargytlar, statuslar we bonuslar.',
        isRu: lang.isRu,
        align: ContentAlign.bottom,
      ),
      TourTarget.build(
        key: _listKey,
        titleRu: 'Список уведомлений',
        titleTk: 'Habarnamalar sanawy',
        bodyRu: 'Нажмите на уведомление чтобы отметить его как прочитанное.',
        bodyTk: 'Habarnama basyň — ol okalandy diýip belleniler.',
        isRu: lang.isRu,
        align: ContentAlign.top,
      ),
    ];
  }

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
          _MarkAllButton(onTap: _markAllRead, label: words.notifMarkAll),
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
    if (_items.isEmpty) return _buildEmpty(words);

    final groups = _groupItems();

    return RefreshIndicator(
      key: _listKey,
      color: c.ink,
      backgroundColor: c.surface,
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          if (groups.today.isNotEmpty) ...[
            _SectionLabel(text: words.notifToday),
            const SizedBox(height: 6),
            ...groups.today.map(
              (n) => _NotifCard(
                key: ValueKey(n['id']),
                notif: n,
                onTap: () {
                  if (n['is_read'] != true) _markRead(n['id'].toString());
                },
              ),
            ),
          ],
          if (groups.yesterday.isNotEmpty) ...[
            if (groups.today.isNotEmpty) const SizedBox(height: 6),
            _SectionLabel(text: words.notifYesterday),
            const SizedBox(height: 6),
            ...groups.yesterday.map(
              (n) => _NotifCard(
                key: ValueKey(n['id']),
                notif: n,
                onTap: () {
                  if (n['is_read'] != true) _markRead(n['id'].toString());
                },
              ),
            ),
          ],
          if (groups.earlier.isNotEmpty) ...[
            if (groups.today.isNotEmpty || groups.yesterday.isNotEmpty)
              const SizedBox(height: 6),
            _SectionLabel(text: words.notifEarlier),
            const SizedBox(height: 6),
            ...groups.earlier.map(
              (n) => _NotifCard(
                key: ValueKey(n['id']),
                notif: n,
                onTap: () {
                  if (n['is_read'] != true) _markRead(n['id'].toString());
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

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
              style: AppText.regular(
                fontSize: 13,
                color: c.inkMuted,
              ).copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section label ─────────────────────────────────────────────────────────────

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
            style: AppText.semiBold(
              fontSize: 10,
              color: c.inkSoft,
            ).copyWith(letterSpacing: 0.8),
          ),
        ],
      ),
    );
  }
}

// ─── Mark-all button ───────────────────────────────────────────────────────────

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
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
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

// ─── Notification card ─────────────────────────────────────────────────────────

class _NotifCard extends StatefulWidget {
  final dynamic notif;
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
    final bool isRead = widget.notif['is_read'] == true;
    final String type = widget.notif['type'] ?? '';
    final c = AppColors.of(context);
    final style = _typeStyle(type, c);

    final String title =
        widget.notif[lang.isRu ? 'title_ru' : 'title_tk'] ??
        widget.notif['title'] ??
        '';
    final String body =
        widget.notif[lang.isRu ? 'body_ru' : 'body_tk'] ??
        widget.notif['body'] ??
        '';
    final String timeStr = notifFormatDate(widget.notif['date_created'], words);

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
            color: isRead ? c.surface : style.icon.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRead ? c.borderSoft : style.icon.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            children: [
              // ── Unread accent bar ──────────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: isRead ? 0 : 3,
                height: 56,
                decoration: BoxDecoration(
                  color: style.icon,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),

              // ── Icon ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: style.bg,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(notifTypeIcon(type), color: style.icon, size: 18),
                ),
              ),

              // ── Text content ───────────────────────────────────────
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
                              title,
                              style: isRead
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
                              if (!isRead) ...[
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
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          body,
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
