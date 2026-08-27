import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Цвета фона и иконки для типа уведомления — **единственный** источник
/// истины. Использует AppColors через BuildContext.
({Color bg, Color icon}) notifTypeStyle(String type, AppColors c) {
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

/// Иконка уведомления.
///
/// [transport] — вид транспорта курьера по этому заказу, если известен.
/// Раньше у всех уведомлений о статусе заказа стоял грузовик, на чём бы
/// человек ни ездил. Теперь иконка совпадает с транспортом; у старых
/// уведомлений транспорта нет, и они остаются с прежней общей иконкой.
IconData notifTypeIcon(String type, {String transport = ''}) {
  switch (type) {
    case 'account_status':
      return Icons.verified_user_rounded;
    case 'new_order':
      return Icons.shopping_bag_rounded;
    case 'order_status':
      return transportIcon(transport);
    case 'daily_bonus':
      return Icons.bolt_rounded;
    case 'trusted_added':
      return Icons.verified_user_outlined;
    case 'referral_paid':
      return Icons.card_giftcard_rounded;
    default:
      return Icons.notifications_rounded;
  }
}

/// Иконка вида транспорта. Пустое значение и всё незнакомое — грузовик,
/// как было раньше: иконка уведомления не должна пропадать из-за того, что
/// транспорт неизвестен.
IconData transportIcon(String transport) {
  switch (transport.trim()) {
    case 'car':
      return Icons.directions_car_rounded;
    case 'truck':
      return Icons.local_shipping_rounded;
    case 'any':
      return Icons.directions_run_rounded;
    default:
      return Icons.local_shipping_rounded;
  }
}

/// True для уведомлений, связанных с конкретным заказом (тап ведёт в заказ).
bool notifIsOrder(String type) => type == 'new_order' || type == 'order_status';

/// Извлекает id заказа из сырых данных уведомления.
///
/// Источник может быть разным: строка из БД (`NotificationDto.raw`) или
/// FCM-payload (`message.data`). Поле может называться по-разному, поэтому
/// проверяем несколько кандидатов. Значение бывает строкой (id) или
/// relation-объектом (`{id: ...}`).
String? notifOrderId(Map<String, dynamic> raw) {
  for (final key in const ['order_id', 'orderId', 'order']) {
    final v = raw[key];
    if (v == null) continue;
    if (v is Map) {
      final id = v['id']?.toString();
      if (id != null && id.isNotEmpty) return id;
      continue;
    }
    final s = v.toString();
    if (s.isNotEmpty && s != 'null') return s;
  }
  return null;
}

String notifFormatDate(String? dateStr, AppLocalizations w) {
  if (dateStr == null) return '';
  try {
    final dt = DateTime.parse(dateStr).toLocal();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return w.notifJustNow;
    if (diff.inMinutes < 60) {
      return w.notifMinAgo.replaceAll('{n}', '${diff.inMinutes}');
    }
    if (diff.inHours < 24) {
      return w.notifHourAgo.replaceAll('{n}', '${diff.inHours}');
    }
    if (diff.inDays < 7) {
      return w.notifDayAgo.replaceAll('{n}', '${diff.inDays}');
    }
    return '${dt.day.toString().padLeft(2, '0')}'
        '.${dt.month.toString().padLeft(2, '0')}'
        '.${dt.year}';
  } catch (_) {
    return '';
  }
}
