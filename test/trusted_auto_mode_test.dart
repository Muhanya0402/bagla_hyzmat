import 'package:bagla/features/orders/order_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Когда заказ автоматически становится «только для надёжных курьеров».
///
/// Здесь сидит защита от мёртвого заказа. Режим включается сам, по сумме, и
/// заказ после этого НЕ открывается всем никогда — так решено сознательно.
/// Если бы он включался у магазина с пустым списком, дорогой заказ стал бы
/// невидим вообще для всех и навсегда, причём магазин ничего не нажимал и не
/// понял бы, почему тишина.
void main() {
  group('OrderService.shouldBeTrustedOnly', () {
    test('дорогой заказ у магазина со списком — включается', () {
      expect(
        OrderService.shouldBeTrustedOnly(
          totalAmount: 500,
          threshold: 300,
          trustedCount: 3,
        ),
        isTrue,
      );
    });

    test('ПУСТОЙ СПИСОК не включает режим — иначе заказ умрёт', () {
      // Самый важный случай во всём наборе.
      expect(
        OrderService.shouldBeTrustedOnly(
          totalAmount: 5000,
          threshold: 300,
          trustedCount: 0,
        ),
        isFalse,
      );
    });

    test('порог 0 выключает режим целиком', () {
      // Рубильник в настройках Directus: пока порог нулевой, вся работа
      // лежит выключенной и включается без пересборки приложения.
      expect(
        OrderService.shouldBeTrustedOnly(
          totalAmount: 100000,
          threshold: 0,
          trustedCount: 10,
        ),
        isFalse,
      );
    });

    test('сумма ровно на пороге — включается', () {
      expect(
        OrderService.shouldBeTrustedOnly(
          totalAmount: 300,
          threshold: 300,
          trustedCount: 1,
        ),
        isTrue,
      );
    });

    test('сумма ниже порога — не включается', () {
      expect(
        OrderService.shouldBeTrustedOnly(
          totalAmount: 299.99,
          threshold: 300,
          trustedCount: 5,
        ),
        isFalse,
      );
    });

    test('дробная сумма сравнивается как число, а не как текст', () {
      expect(
        OrderService.shouldBeTrustedOnly(
          totalAmount: 1000.5,
          threshold: 300,
          trustedCount: 1,
        ),
        isTrue,
      );
    });

    test('нулевая сумма при нулевом пороге не включает режим', () {
      // 0 >= 0 истинно, и без явной проверки порога заказ на ноль манат
      // спрятался бы от всех курьеров.
      expect(
        OrderService.shouldBeTrustedOnly(
          totalAmount: 0,
          threshold: 0,
          trustedCount: 5,
        ),
        isFalse,
      );
    });
  });
}
