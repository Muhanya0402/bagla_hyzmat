import 'package:bagla/core/api_client.dart';
import 'package:flutter/foundation.dart';

/// Причина жалобы. Список закрытый — иначе сервер не сможет считать баллы.
enum ReportReason {
  rude('rude'),
  extortion('extortion'),
  noDoor('no_door'),
  late('late'),
  noContact('no_contact'),
  notDelivered('not_delivered');

  final String id;
  const ReportReason(this.id);
}

/// Жалобы магазина на курьера и отстранение курьера модератором.
///
/// Жалоба пишется прямо в коллекцию: разбирает её флоу на сервере — он же
/// и проверяет право жаловаться. Подделать чужую жалобу бессмысленно: если
/// заказ не этого магазина или курьер его не вёз, флоу пометит запись
/// отклонённой и баллов никому не начислит.
///
/// Отстранять курьеров приложение не умеет намеренно: это делается в
/// панели, командой на карточке пользователя. Так право закрыть человеку
/// доступ не зависит от того, что можно послать с телефона.
class CourierReportService {
  final ApiClient _api = ApiClient();

  /// Сколько часов после закрытия заказа можно жаловаться.
  /// Столько же проверяет сервер — здесь только чтобы не показывать кнопку,
  /// которая заведомо ничего не даст.
  static const int reportWindowHours = 24;

  /// Можно ли ещё пожаловаться на этот заказ.
  static bool canReport({
    required String status,
    required String? closedAt,
    required String courierId,
  }) {
    if (courierId.isEmpty) return false;
    if (status != 'completed' && status != 'canceled') return false;
    if (closedAt == null || closedAt.isEmpty) return false;
    final t = DateTime.tryParse(closedAt);
    if (t == null) return false;
    return DateTime.now().difference(t.toLocal()).inHours < reportWindowHours;
  }

  Future<bool> sendReport({
    required String orderId,
    required String courierId,
    required String shopId,
    required ReportReason reason,
    String comment = '',
  }) async {
    try {
      await _api.dio.post('/items/courier_reports', data: {
        'order_id': int.tryParse(orderId) ?? orderId,
        'courier_id': int.tryParse(courierId) ?? courierId,
        'shop_id': int.tryParse(shopId) ?? shopId,
        'reason': reason.id,
        if (comment.isNotEmpty) 'comment': comment,
      });
      return true;
    } catch (e) {
      if (kDebugMode) print('CourierReportService.sendReport: $e');
      return false;
    }
  }
}
