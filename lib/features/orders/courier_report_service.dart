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
/// Отстранение идёт только через флоу: право менять чужую учётку у
/// приложения не выдано, и сервер сам проверяет, что нажимал модератор.
class CourierReportService {
  final ApiClient _api = ApiClient();

  /// Флоу «Отстранить курьера».
  static const String blockFlowId = 'c87d76db-7d3f-44af-9d01-2356c6b2d73d';

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

  /// Отстранить курьера на [days] суток. Доступно только модератору —
  /// проверку делает сервер, здесь мы лишь передаём, кто нажал.
  Future<bool> blockCourier({
    required String courierId,
    required int days,
    required String moderatorId,
  }) async {
    try {
      await _api.dio.post('/flows/trigger/$blockFlowId', data: {
        'courier_id': int.tryParse(courierId) ?? courierId,
        'days': days,
        'moderator_id': int.tryParse(moderatorId) ?? moderatorId,
      });
      return true;
    } catch (e) {
      if (kDebugMode) print('CourierReportService.blockCourier: $e');
      return false;
    }
  }
}
