import 'package:bagla/core/tour/tour_manager.dart';
import 'package:bagla/features/auth/logout_prefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// TourManager — синглтон, он кеширует экземпляр prefs при первом init().
/// `setMockInitialValues` создаёт НОВЫЙ объект prefs, и тест начал бы писать
/// не туда, куда смотрит TourManager. Поэтому мок ставим один раз, а между
/// тестами просто чистим тот же самый экземпляр.
Future<SharedPreferences> freshPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  await TourManager.instance.init();
  return prefs;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final tm = TourManager.instance;

  test('namespace берётся из prefs, даже если setUserId не звали', () async {
    final prefs = await freshPrefs();
    await prefs.setString('user_id', '253');

    tm.setUserId(''); // эмулируем рассинхрон: поле пустое
    await tm.markSeen('home_screen');

    expect(prefs.getBool('tour_passed_253_home_screen'), isTrue,
        reason: 'ключ должен быть привязан к id из prefs');
    expect(tm.isSeen('home_screen'), isTrue);
  });

  test('пройден -> logout -> вход: гид не повторяется', () async {
    final prefs = await freshPrefs();
    await prefs.setString('user_id', '253');
    await prefs.setString('role', 'courier');
    tm.setUserId('253');
    await tm.markSeen('home_screen');
    await tm.markSeen('profile_screen');

    await clearAccountPrefs(prefs); // выход
    tm.setUserId('');
    expect(prefs.getString('user_id'), isNull);

    // Вход: prefs пишутся раньше, чем кто-либо вызвал setUserId.
    await prefs.setString('user_id', '253');
    expect(tm.isSeen('home_screen'), isTrue);
    expect(tm.isSeen('profile_screen'), isTrue);
  });

  test('другой аккаунт на том же устройстве видит гид', () async {
    final prefs = await freshPrefs();
    await prefs.setString('user_id', '253');
    tm.setUserId('253');
    await tm.markSeen('home_screen');

    await prefs.setString('user_id', '999');
    tm.setUserId('999');
    expect(tm.isSeen('home_screen'), isFalse,
        reason: 'новому пользователю гид показать нужно');
  });
}
