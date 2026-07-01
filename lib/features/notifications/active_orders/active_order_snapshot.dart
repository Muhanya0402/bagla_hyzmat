import 'dart:convert';

/// Лёгкий снимок заказа для persistent notification.
///
/// Намеренно НЕ переиспользует `OrderDto` — `OrderDto` тяжёлый, содержит
/// `raw` Map и много полей, не нужных в шторке. Здесь — только то, что
/// уместится в заголовок + подзаголовок + 2 кнопки.
///
/// Сериализуется в SharedPreferences (JSON-список), чтобы background isolate
/// мог читать актуальный набор активных заказов без обращения к Provider/Dio.
class ActiveOrderSnapshot {
  final String id;
  final String shortId;
  /// Адрес доставки в текущем языке (RU или TK) — заранее зафиксирован
  /// при сохранении, чтобы background isolate не таскал LanguageProvider.
  final String addressLine;
  /// Телефон для кнопки «Позвонить». Пустая строка — кнопка не показывается.
  /// Для курьера это телефон клиента, для магазина — телефон курьера.
  final String phoneToCall;
  /// ID курьера (customer id). Нужен для `generateDeliveryCode` из
  /// background isolate'а при нажатии «Завершить». Пустая строка у магазина.
  final String courierId;
  /// Статус — 'published' / 'active' / etc. Влияет на доступные действия.
  final String status;

  /// Дедлайн доставки (ISO-8601, как `time_of_delivery`). Пустая строка —
  /// дедлайна нет (тогда таймер обратного отсчёта не показывается).
  /// Время остатка считается при каждой перерисовке уведомления.
  final String deadline;

  const ActiveOrderSnapshot({
    required this.id,
    required this.shortId,
    required this.addressLine,
    required this.phoneToCall,
    required this.courierId,
    required this.status,
    this.deadline = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'shortId': shortId,
        'addressLine': addressLine,
        'phoneToCall': phoneToCall,
        'courierId': courierId,
        'status': status,
        'deadline': deadline,
      };

  factory ActiveOrderSnapshot.fromJson(Map<String, dynamic> j) =>
      ActiveOrderSnapshot(
        id: (j['id'] ?? '').toString(),
        shortId: (j['shortId'] ?? '').toString(),
        addressLine: (j['addressLine'] ?? '').toString(),
        phoneToCall: (j['phoneToCall'] ?? '').toString(),
        courierId: (j['courierId'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        deadline: (j['deadline'] ?? '').toString(),
      );

  static String encodeList(List<ActiveOrderSnapshot> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<ActiveOrderSnapshot> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((e) => ActiveOrderSnapshot.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
