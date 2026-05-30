/// Типизированное представление уведомления.
///
/// API возвращает `List<dynamic>`, где каждый элемент — `Map<String, dynamic>`.
/// `NotificationDto.fromMap` инкапсулирует все string-key lookups в одном месте
/// и даёт остальному коду строгий API.
class NotificationDto {
  final String id;
  final String type;
  final String titleRu;
  final String titleTk;
  final String bodyRu;
  final String bodyTk;
  final DateTime? createdAt;
  final bool isRead;
  // Сырая мапа — на случай если где-то понадобится поле, которого нет в DTO.
  final Map<String, dynamic> raw;

  const NotificationDto({
    required this.id,
    required this.type,
    required this.titleRu,
    required this.titleTk,
    required this.bodyRu,
    required this.bodyTk,
    required this.createdAt,
    required this.isRead,
    required this.raw,
  });

  factory NotificationDto.fromMap(Map<String, dynamic> m) {
    DateTime? parsed;
    try {
      final raw = m['date_created']?.toString();
      if (raw != null && raw.isNotEmpty) {
        parsed = DateTime.parse(raw).toLocal();
      }
    } catch (_) {
      parsed = null;
    }

    String pick(String a, String b) {
      final va = (m[a] ?? '').toString();
      if (va.isNotEmpty) return va;
      final vb = (m[b] ?? '').toString();
      return vb;
    }

    return NotificationDto(
      id: (m['id'] ?? '').toString(),
      type: (m['type'] ?? '').toString(),
      titleRu: pick('title_ru', 'title'),
      titleTk: pick('title_tk', 'title'),
      bodyRu: pick('body_ru', 'body'),
      bodyTk: pick('body_tk', 'body'),
      createdAt: parsed,
      isRead: m['is_read'] == true,
      raw: m,
    );
  }

  String title(bool isRu) => isRu ? titleRu : titleTk;
  String body(bool isRu) => isRu ? bodyRu : bodyTk;

  /// Возвращает копию с указанными перезаписанными полями.
  NotificationDto copyWith({bool? isRead}) => NotificationDto(
        id: id,
        type: type,
        titleRu: titleRu,
        titleTk: titleTk,
        bodyRu: bodyRu,
        bodyTk: bodyTk,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
        raw: raw,
      );
}
