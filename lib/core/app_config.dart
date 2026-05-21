// Все чувствительные константы — в одном месте.
// В продакшне заменить на flutter_dotenv или --dart-define.
class AppConfig {
  // Статический токен для публичных эндпоинтов (OTP отправка/верификация).
  // Не даёт доступа к данным пользователей — только к /items/otp_codes и flow.
  static const String publicToken = '8TYMndErscy0GgMcVcO1u_jLD-6GaqMD';
}
