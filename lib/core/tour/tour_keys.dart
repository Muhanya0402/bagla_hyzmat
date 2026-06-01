/// Типизированные ключи экранов для тур-системы.
/// Добавляй новую строку при создании каждого нового экрана.
abstract final class TourKeys {
  static const home               = 'home_screen';
  static const profile            = 'profile_screen';
  static const orderDetail        = 'order_detail_screen';
  static const notifications      = 'notifications_screen';
  static const createOrder        = 'create_order_screen';
  static const appeals            = 'appeals_screen';
  static const topUpModal         = 'top_up_modal';
  static const courierFilter      = 'courier_filter_modal';
  static const userTypeSelection  = 'user_type_selection_screen';

  /// SharedPrefs-ключ для тур-состояния.
  ///
  /// Если передан непустой `userId`, ключ становится account-scoped:
  ///   `tour_passed_<userId>_<screen>`.
  /// Иначе — глобальный (legacy): `tour_passed_<screen>`.
  /// Account-scoping важен на устройствах, где работают через несколько
  /// аккаунтов: после logout→login другого аккаунта тур должен сбрасываться
  /// **только для нового пользователя**, а у вернувшегося — оставаться seen.
  static String prefsKey(String screenKey, {String userId = ''}) {
    if (userId.isEmpty) return 'tour_passed_$screenKey';
    return 'tour_passed_${userId}_$screenKey';
  }

  /// Префикс для bulk-поиска всех tour-ключей (любого пользователя).
  static const prefsPrefix = 'tour_passed_';
}
