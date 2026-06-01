/// Стабильные коды причин отказа модератора.
///
/// Используются как массив строк в поле `customers.rejection_reasons`
/// (в Directus — JSON-массив или CSV-string). При показе экрана
/// исправления каждый код мапится на конкретную секцию /
/// поле в `RegistrationDetailsScreen` — модератор тыкает чекбоксы,
/// пользователь правит только нужное.
///
/// Локализованные подписи живут в l10n (`words.rejectionReason<Code>`).
/// Иконки подбираются в UI по коду (см. `iconForRejectionCode`).
abstract final class RejectionCode {
  // ── Общие (для обеих ролей) ─────────────────────────────────────────────
  static const location = 'location';

  // ── Курьер ──────────────────────────────────────────────────────────────
  static const name = 'name';
  static const surname = 'surname';
  static const lastname = 'lastname';
  static const transportType = 'transport_type';
  static const passportMain = 'passport_main';
  static const passportAddress = 'passport_address';
  static const passportFace = 'passport_face';
  static const selfie = 'selfie';

  // ── Магазин ─────────────────────────────────────────────────────────────
  static const organizationName = 'organization_name';
  static const category = 'category';

  /// Все возможные коды для курьера. Используется модератором как чек-лист.
  static const Set<String> courierAll = {
    name,
    surname,
    lastname,
    location,
    transportType,
    passportMain,
    passportAddress,
    passportFace,
    selfie,
  };

  /// Все возможные коды для магазина.
  static const Set<String> shopAll = {
    organizationName,
    location,
    category,
  };
}
