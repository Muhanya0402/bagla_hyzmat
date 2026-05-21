import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/notifications/notification_service.dart';
import 'package:bagla/features/notifications/widgets/notification_helpers.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _service = NotificationService();

  List<dynamic> _items = [];
  bool _isLoading = true;
  late String _userId;

  @override
  void initState() {
    super.initState();
    _userId = context.read<AuthProvider>().userId;
    _loadNotifications();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Уведомления',
          style: AppText.semiBold(fontSize: 17, color: const Color(0xFF0F1117)),
        ),
        actions: [
          GestureDetector(
            onTap: _markAllRead,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: kNotifGreen.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kNotifGreen.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.done_all_rounded,
                    color: kNotifGreen,
                    size: 14,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Прочитать все',
                    style: AppText.semiBold(fontSize: 12, color: kNotifGreen),
                  ),
                ],
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: const Color(0xFFEEF0F3)),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: kNotifGreen, strokeWidth: 2),
      );
    }
    if (_items.isEmpty) return _buildEmpty();

    final today = <dynamic>[];
    final earlier = <dynamic>[];
    final now = DateTime.now();

    for (final n in _items) {
      try {
        final dt = DateTime.parse(
          (n['date_created'] ?? '').toString(),
        ).toLocal();
        if (now.difference(dt).inHours < 24) {
          today.add(n);
        } else {
          earlier.add(n);
        }
      } catch (_) {
        earlier.add(n);
      }
    }

    return RefreshIndicator(
      color: kNotifGreen,
      backgroundColor: Colors.white,
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          if (today.isNotEmpty) ...[
            _sectionLabel('СЕГОДНЯ'),
            const SizedBox(height: 8),
            ...today.map(
              (n) => _NotifCard(
                key: ValueKey(n['id']),
                notif: n,
                onTap: () {
                  if (n['is_read'] != true) _markRead(n['id'].toString());
                },
              ),
            ),
          ],
          if (earlier.isNotEmpty) ...[
            const SizedBox(height: 8),
            _sectionLabel('РАНЕЕ'),
            const SizedBox(height: 8),
            ...earlier.map(
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

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Row(
      children: [
        Container(
          width: 3,
          height: 12,
          decoration: BoxDecoration(
            gradient: kNotifGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: kNotifGrey,
            letterSpacing: 0.8,
          ),
        ),
      ],
    ),
  );

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEEF0F3)),
            ),
            child: Icon(
              Icons.notifications_off_rounded,
              size: 32,
              color: kNotifGrey.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Уведомлений пока нет',
            style: AppText.semiBold(fontSize: 15, color: kNotifGrey),
          ),
          const SizedBox(height: 6),
          Text(
            'Здесь будут уведомления\nо заказах и статусе аккаунта',
            textAlign: TextAlign.center,
            style: AppText.regular(fontSize: 13, color: kNotifGrey),
          ),
        ],
      ),
    );
  }
}

// ─── Карточка уведомления ──────────────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  final dynamic notif;
  final VoidCallback onTap;

  const _NotifCard({super.key, required this.notif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool isRead = notif['is_read'] == true;
    final String type = notif['type'] ?? '';
    final Color color = notifTypeColor(type);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : color.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead
                ? const Color(0xFFEEF0F3)
                : color.withValues(alpha: 0.2),
          ),
          boxShadow: isRead
              ? null
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          children: [
            if (!isRead)
              Container(
                height: 2,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(notifTypeIcon(type), color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.09),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                notifTypeLabel(type),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (!isRead)
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.4),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notif['title_ru'] ?? notif['title'] ?? '',
                          style: isRead
                              ? AppText.medium(
                                  fontSize: 14,
                                  color: const Color(0xFF0F1117),
                                )
                              : AppText.bold(
                                  fontSize: 14,
                                  color: const Color(0xFF0F1117),
                                ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          notif['body_ru'] ?? notif['body'] ?? '',
                          style: AppText.regular(
                            fontSize: 13,
                            color: kNotifGrey,
                          ).copyWith(height: 1.4),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 11,
                              color: Color(0xFFD1D5DB),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              notifFormatDate(notif['date_created']),
                              style: AppText.regular(
                                fontSize: 11,
                                color: const Color(0xFFD1D5DB),
                              ),
                            ),
                            if (!isRead) ...[
                              const Spacer(),
                              Text(
                                'Нажмите, чтобы отметить',
                                style: AppText.regular(
                                  fontSize: 10,
                                  color: color.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
