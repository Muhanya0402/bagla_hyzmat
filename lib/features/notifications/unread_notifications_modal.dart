import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/notifications/notification_service.dart';
import 'package:flutter/material.dart';

class UnreadNotificationsModal extends StatelessWidget {
  final List<Map<String, dynamic>> notifications;
  final VoidCallback onMarkAllRead;

  static const _green = Color(0xFF1A7A3C);
  static const _red = Color(0xFFD32F1E);
  static const _gradient = LinearGradient(colors: [_green, _red]);

  const UnreadNotificationsModal({
    super.key,
    required this.notifications,
    required this.onMarkAllRead,
  });

  Color _typeColor(String type) {
    switch (type) {
      case 'daily_bonus':
        return const Color(0xFFE67E22);
      case 'new_order':
        return _green;
      case 'order_status':
        return _red;
      case 'account_status':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF9AA3AF);
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'daily_bonus':
        return Icons.bolt_rounded;
      case 'new_order':
        return Icons.shopping_bag_rounded;
      case 'order_status':
        return Icons.local_shipping_rounded;
      case 'account_status':
        return Icons.verified_user_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: _gradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.notifications_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (b) => _gradient.createShader(b),
                      child: Text(
                        'Новые уведомления',
                        style: AppText.bold(fontSize: 16, color: Colors.white),
                      ),
                    ),
                    Text(
                      '${notifications.length} непрочитанных',
                      style: AppText.regular(
                        fontSize: 12,
                        color: const Color(0xFF9AA3AF),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFEEF0F3)),

          // List
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                indent: 72,
                color: Color(0xFFEEF0F3),
              ),
              itemBuilder: (_, i) {
                final n = notifications[i];
                final type = n['type'] ?? '';
                final color = _typeColor(type);
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_typeIcon(type), color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n['title_ru'] ?? n['title'] ?? '',
                              style: AppText.semiBold(
                                fontSize: 14,
                                color: const Color(0xFF0F1117),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              n['body_ru'] ?? n['body'] ?? '',
                              style: AppText.regular(
                                fontSize: 12,
                                color: const Color(0xFF9AA3AF),
                              ).copyWith(height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1, color: Color(0xFFEEF0F3)),
          const SizedBox(height: 16),

          // Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFEEF0F3)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Закрыть',
                        style: AppText.semiBold(
                          fontSize: 14,
                          color: const Color(0xFF9AA3AF),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      onMarkAllRead();
                      Navigator.pop(context);
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: _gradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Прочитать все',
                        style: AppText.semiBold(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
