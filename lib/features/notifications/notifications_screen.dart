import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/notifications/notification_service.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // ── Brand ──────────────────────────────────────────────────────────────────
  static const _green = Color(0xFF1A7A3C);
  static const _red = Color(0xFFD32F1E);
  static const _grey = Color(0xFF9AA3AF);
  static const _gradient = LinearGradient(colors: [_green, _red]);

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

  // ── Type helpers ───────────────────────────────────────────────────────────

  Color _typeColor(String type) {
    switch (type) {
      case 'account_status':
        return const Color(0xFF7C3AED);
      case 'new_order':
        return _green;
      case 'order_status':
        return _red;
      case 'daily_bonus':
        return const Color(0xFFE67E22);
      default:
        return _grey;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'account_status':
        return Icons.verified_user_rounded;
      case 'new_order':
        return Icons.shopping_bag_rounded;
      case 'order_status':
        return Icons.local_shipping_rounded;
      case 'daily_bonus':
        return Icons.bolt_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'account_status':
        return 'Аккаунт';
      case 'new_order':
        return 'Новый заказ';
      case 'order_status':
        return 'Статус заказа';
      case 'daily_bonus':
        return 'Ежедневный бонус';
      default:
        return 'Уведомление';
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Только что';
      if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
      if (diff.inHours < 24) return '${diff.inHours} ч назад';
      if (diff.inDays < 7) return '${diff.inDays} дн назад';
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (_) {
      return '';
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // ✅ leading убран — уведомления теперь таб в BottomNavigationBar
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
                color: _green.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _green.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.done_all_rounded, color: _green, size: 14),
                  const SizedBox(width: 5),
                  Text(
                    'Прочитать все',
                    style: AppText.semiBold(fontSize: 12, color: _green),
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
        child: CircularProgressIndicator(color: _green, strokeWidth: 2),
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
      color: _green,
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
                color: _typeColor(n['type'] ?? ''),
                icon: _typeIcon(n['type'] ?? ''),
                label: _typeLabel(n['type'] ?? ''),
                dateStr: _formatDate(n['date_created']),
                onTap: () {
                  if (n['is_read'] != true) {
                    _markRead(n['id'].toString());
                  }
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
                color: _typeColor(n['type'] ?? ''),
                icon: _typeIcon(n['type'] ?? ''),
                label: _typeLabel(n['type'] ?? ''),
                dateStr: _formatDate(n['date_created']),
                onTap: () {
                  if (n['is_read'] != true) {
                    _markRead(n['id'].toString());
                  }
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
            gradient: _gradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Color(0xFF9AA3AF),
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
              color: _grey.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Уведомлений пока нет',
            style: AppText.semiBold(fontSize: 15, color: _grey),
          ),
          const SizedBox(height: 6),
          Text(
            'Здесь будут уведомления\nо заказах и статусе аккаунта',
            textAlign: TextAlign.center,
            style: AppText.regular(fontSize: 13, color: _grey),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification card
// ─────────────────────────────────────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  final dynamic notif;
  final Color color;
  final IconData icon;
  final String label;
  final String dateStr;
  final VoidCallback onTap;

  const _NotifCard({
    super.key,
    required this.notif,
    required this.color,
    required this.icon,
    required this.label,
    required this.dateStr,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isRead = notif['is_read'] == true;

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
                    child: Icon(icon, color: color, size: 20),
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
                                label,
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
                            color: const Color(0xFF9AA3AF),
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
                              dateStr,
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
