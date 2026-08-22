import 'package:bagla/core/tour/tour_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('гид не показывается повторно после logout -> login на тот же аккаунт',
      () async {
    SharedPreferences.setMockInitialValues({});
    final tm = TourManager.instance;
    await tm.init();

    tm.setUserId('253');
    await tm.markSeen('home_screen');
    expect(tm.isSeen('home_screen'), isTrue);

    // Logout: снимок -> clear -> восстановление (как в AuthProvider).
    final snapshot = tm.snapshotAllTourKeys();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await tm.restoreSnapshot(snapshot);
    tm.setUserId('');

    tm.setUserId('253');
    expect(tm.isSeen('home_screen'), isTrue);
  });

  test('гонка: гид стартует ДО записи user_id в prefs', () async {
    SharedPreferences.setMockInitialValues({});
    final tm = TourManager.instance;
    await tm.init();

    // Пользователь уже проходил гид на этом аккаунте.
    tm.setUserId('253');
    await tm.markSeen('home_screen');

    // Logout.
    final snapshot = tm.snapshotAllTourKeys();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await tm.restoreSnapshot(snapshot);
    tm.setUserId('');

    // Повторный вход: setUserData выставляет namespace СРАЗУ (наш фикс),
    // а `user_id` в prefs ещё НЕ записан — цепочка await не завершилась.
    tm.setUserId('253');
    expect(prefs.getString('user_id'), isNull, reason: 'prefs ещё не записаны');

    // Так ведёт себя _tryLaunch: пустой uid из prefs namespace не перетирает.
    final uid = prefs.getString('user_id') ?? '';
    if (uid.isNotEmpty) tm.setUserId(uid);

    expect(tm.isSeen('home_screen'), isTrue,
        reason: 'гид уже пройден — показывать повторно нельзя');
  });
}
