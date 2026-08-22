import 'package:bagla/core/tour/tour_manager.dart';
import 'package:bagla/features/auth/logout_prefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('logout удаляет данные аккаунта, но сохраняет гиды и настройки',
      () async {
    SharedPreferences.setMockInitialValues({
      // тур-состояния двух разных пользователей
      'tour_passed_253_home_screen': true,
      'tour_passed_253_profile_screen': true,
      'tour_passed_999_home_screen': true,
      // настройки устройства
      'onboarding_done': true,
      'is_dark_mode': true,
      'selected_lang': 'ru',
      // данные аккаунта — должны уйти
      'user_id': '253',
      'role': 'courier',
      'balance_points': 10.0,
      'is_logged_in': true,
    });

    final prefs = await SharedPreferences.getInstance();
    await clearAccountPrefs(prefs);

    // Гиды целы — у всех пользователей устройства.
    expect(prefs.getBool('tour_passed_253_home_screen'), isTrue);
    expect(prefs.getBool('tour_passed_253_profile_screen'), isTrue);
    expect(prefs.getBool('tour_passed_999_home_screen'), isTrue);
    // Настройки устройства целы.
    expect(prefs.getBool('onboarding_done'), isTrue);
    expect(prefs.getBool('is_dark_mode'), isTrue);
    expect(prefs.getString('selected_lang'), 'ru');
    // Данные аккаунта удалены.
    expect(prefs.getString('user_id'), isNull);
    expect(prefs.getString('role'), isNull);
    expect(prefs.getDouble('balance_points'), isNull);
    expect(prefs.getBool('is_logged_in'), isNull);
  });

  test('после logout->login тот же аккаунт не показывает гид заново', () async {
    SharedPreferences.setMockInitialValues({});
    final tm = TourManager.instance;
    await tm.init();

    tm.setUserId('253');
    await tm.markSeen('home_screen');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', '253');

    // Выход по новой схеме.
    await clearAccountPrefs(prefs);
    tm.setUserId('');

    // Повторный вход.
    tm.setUserId('253');
    expect(tm.isSeen('home_screen'), isTrue);
  });
}
