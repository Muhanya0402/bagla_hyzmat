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

  /// SharedPrefs-ключ: 'tour_passed_home_screen' и т.д.
  static String prefsKey(String screenKey) => 'tour_passed_$screenKey';
}
