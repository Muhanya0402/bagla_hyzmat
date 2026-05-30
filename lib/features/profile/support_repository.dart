import 'package:bagla/core/api_client.dart';

/// Тонкая обёртка над API «Обращения в поддержку».
class SupportRepository {
  final ApiClient _api = ApiClient();

  /// Отправляет обращение пользователя. Бросает исключение при ошибке.
  Future<void> sendAppeal({
    required String userId,
    required String subject,
    required String body,
  }) async {
    await _api.dio.post(
      '/items/appeals',
      data: {
        'user_id': int.tryParse(userId) ?? userId,
        'subject': subject,
        'body': body,
        'status': 'open',
      },
    );
  }
}
