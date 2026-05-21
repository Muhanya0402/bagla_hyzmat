import 'package:flutter/material.dart';

const Color kNotifGreen = Color(0xFF1A7A3C);
const Color kNotifRed = Color(0xFFD32F1E);
const Color kNotifGrey = Color(0xFF9AA3AF);
const Color kNotifOrange = Color(0xFFE67E22);
const Color kNotifPurple = Color(0xFF7C3AED);

const LinearGradient kNotifGradient = LinearGradient(
  colors: [kNotifGreen, kNotifRed],
);

Color notifTypeColor(String type) {
  switch (type) {
    case 'account_status':
      return kNotifPurple;
    case 'new_order':
      return kNotifGreen;
    case 'order_status':
      return kNotifRed;
    case 'daily_bonus':
      return kNotifOrange;
    default:
      return kNotifGrey;
  }
}

IconData notifTypeIcon(String type) {
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

String notifTypeLabel(String type) {
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

String notifFormatDate(String? dateStr) {
  if (dateStr == null) return '';
  try {
    final dt = DateTime.parse(dateStr).toLocal();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
    if (diff.inHours < 24) return '${diff.inHours} ч назад';
    if (diff.inDays < 7) return '${diff.inDays} дн назад';
    return '${dt.day.toString().padLeft(2, '0')}'
        '.${dt.month.toString().padLeft(2, '0')}'
        '.${dt.year}';
  } catch (_) {
    return '';
  }
}
