import 'package:bagla/features/orders/order_dto.dart';
import 'package:bagla/features/orders/order_service.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'active_order_snapshot.dart';
import 'active_orders_notification.dart';

/// Сборка актуального списка активных заказов и синхронизация
/// persistent-уведомления «Активные заказы».
///
/// Намеренно НЕ зависит от Provider / BuildContext — поэтому работает
/// одинаково и в foreground (контроллер home), и в **FCM background
/// isolate** (когда приложение свёрнуто/выгружено). Это чинит баг:
/// у заказчика число активных заказов в уведомлении не обновлялось, пока
/// он не зайдёт в приложение (в фоне WebSocket отключён, а пуш о смене
/// статуса теперь триггерит этот пересчёт).
abstract final class ActiveOrdersSync {
  ActiveOrdersSync._();

  /// Пересобрать снимки и обновить уведомление для заданного пользователя.
  static Future<void> run({
    required String role,
    required String userId,
    required AppLocale locale,
  }) async {
    if (userId.isEmpty) {
      await ActiveOrdersNotification.hide();
      return;
    }
    final isCourier = role.toLowerCase().trim() == 'courier';
    final isRu = locale == AppLocale.ru;
    final words = AppLocalizations(locale);

    // Полный список активных заказов — независимо от пагинации ленты.
    final activeRaw =
        await OrderService().getActiveOrders(role: role, userId: userId);

    final snapshots = <ActiveOrderSnapshot>[];
    for (final raw in activeRaw) {
      if (raw is! Map) continue;
      final dto = OrderDto.fromMap(Map<String, dynamic>.from(raw));
      snapshots.add(
        ActiveOrderSnapshot(
          id: dto.id,
          shortId: dto.shortId,
          addressLine: dto.deliveryAddress(isRu),
          // Курьеру звоним клиенту, магазину — курьеру.
          phoneToCall: isCourier ? dto.clientPhone : dto.courierPhone,
          status: dto.status,
          deadline: dto.timeOfDelivery ?? '',
          courierId: isCourier ? userId : '',
        ),
      );
    }

    await ActiveOrdersNotification.sync(
      orders: snapshots,
      title: words.activeOrdersNotifTitle,
      indexTemplate: (i, n) => words.activeOrdersIndex
          .replaceAll('{i}', '${i + 1}')
          .replaceAll('{n}', '$n'),
      callBtnLabel: words.activeOrdersBtnCall,
      completeBtnLabel: words.activeOrdersBtnComplete,
      verifyBtnLabel: words.activeOrdersBtnVerify,
      enterCodeTitle: words.activeOrdersEnterCodeTitle,
      codeSentBody: words.activeOrdersCodeSentBody,
      completedBody: words.activeOrdersCompleted,
      timeLeftLabel: words.activeOrdersTimeLeft,
      timeExpiredLabel: words.activeOrdersTimeExpired,
    );
  }

  /// Версия для background isolate: сама читает role / userId / язык из prefs.
  /// Безопасна для вызова из FCM background handler.
  static Future<void> runFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';
    if (userId.isEmpty) return;
    final role = prefs.getString('role') ?? 'client';
    // Клиенту persistent-уведомление не показываем — нечего синхронизировать.
    final r = role.toLowerCase().trim();
    if (r != 'courier' && r != 'shop' && r != 'business') return;
    final lang = prefs.getString('selected_lang') ?? 'ru';
    final locale = lang == 'ru' ? AppLocale.ru : AppLocale.tk;
    await run(role: role, userId: userId, locale: locale);
  }
}
