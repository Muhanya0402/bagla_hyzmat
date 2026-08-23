import 'package:bagla/features/orders/order_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Исчезновение занятого заказа из чужой ленты держалось только на WebSocket.
/// Он на мобильной сети подвисает — соединение живо, события не идут, — и
/// курьер продолжал видеть заказ, который уже забрали.
///
/// Теперь лента раз в 25 секунд сверяется с сервером. Эти тесты закрепляют
/// решающее место сверки: что именно убирать из ленты, а когда не трогать
/// ничего.
void main() {
  group('OrderService.ordersToDrop', () {
    test('убираем те, кого больше нет среди свободных', () {
      final drop = OrderService.ordersToDrop(
        ['1', '2', '3'],
        {'1', '3'},
      );
      expect(drop, {'2'});
    });

    test('все свободны — не убираем ничего', () {
      expect(
        OrderService.ordersToDrop(['1', '2'], {'1', '2'}),
        isEmpty,
      );
    });

    test('все заняты — убираем все', () {
      expect(
        OrderService.ordersToDrop(['1', '2'], <String>{}),
        {'1', '2'},
      );
    });

    test('СВЕРКА НЕ УДАЛАСЬ (null) — лента остаётся нетронутой', () {
      // Самый важный случай. Если трактовать null как «свободных нет»,
      // единственный сетевой сбой стёр бы курьеру все доступные заказы.
      expect(OrderService.ordersToDrop(['1', '2', '3'], null), isEmpty);
    });

    test('пустой экран — убирать нечего', () {
      expect(OrderService.ordersToDrop([], {'1'}), isEmpty);
      expect(OrderService.ordersToDrop([], null), isEmpty);
    });
  });
}
