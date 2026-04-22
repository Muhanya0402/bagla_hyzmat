import 'package:bagla/features/notifications/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const Color brandBlue = Color(0xFF1B3A6B);
  static const Color brandGreen = Color(0xFF27AE60);

  final NotificationService _service = NotificationService();
  late Future<List<dynamic>> _future;
  late String _userId;

  @override
  void initState() {
    super.initState();
    _userId = context.read<AuthProvider>().userId;
    _future = _service.getNotifications(_userId);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _service.getNotifications(_userId);
    });
  }

  Future<void> _markAllRead() async {
    await _service.markAllAsRead(_userId);
    _refresh();
  }

  Future<void> _markRead(String id) async {
    await _service.markAsRead(id);
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'account_status':
        return const Color(0xFF5B2D9E);
      case 'new_order':
        return brandGreen;
      case 'order_status':
        return brandBlue;
      default:
        return const Color(0xFF9AA3AF);
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'account_status':
        return Icons.person_rounded;
      case 'new_order':
        return Icons.shopping_bag_rounded;
      case 'order_status':
        return Icons.local_shipping_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Только что';
      if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
      if (diff.inHours < 24) return '${diff.inHours} ч назад';
      if (diff.inDays < 7) return '${diff.inDays} дн назад';
      return '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: brandBlue.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: brandBlue,
              size: 18,
            ),
          ),
        ),
        title: Text(
          'Уведомления',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F1117),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: Text(
              'Прочитать все',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: brandGreen,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: const Color(0xFFEEF0F3)),
        ),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: brandGreen,
                strokeWidth: 2,
              ),
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                      color: brandBlue.withOpacity(0.2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Уведомлений пока нет',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF9AA3AF),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: brandGreen,
            backgroundColor: Colors.white,
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final n = notifications[index];
                final bool isRead = n['is_read'] == true;
                final String type = n['type'] ?? '';
                final Color color = _typeColor(type);

                return GestureDetector(
                  onTap: () async {
                    if (!isRead) {
                      await _markRead(n['id'].toString());
                      _refresh();
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isRead ? Colors.white : color.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isRead
                            ? const Color(0xFFEEF0F3)
                            : color.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Иконка типа
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(_typeIcon(type), color: color, size: 20),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      n['title'] ?? '',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: isRead
                                            ? FontWeight.w500
                                            : FontWeight.w700,
                                        color: const Color(0xFF0F1117),
                                      ),
                                    ),
                                  ),
                                  if (!isRead)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                n['body'] ?? '',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF9AA3AF),
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatDate(n['date_created']),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFFD1D5DB),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
