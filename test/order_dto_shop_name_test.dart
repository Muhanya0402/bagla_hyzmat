import 'package:bagla/features/orders/order_dto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Имя заказчика попадает в заказ тремя разными путями, потому что сам
/// заказ приходит в приложение по-разному: загрузкой списка с сервера, по
/// WebSocket и из кэша. Курьеру имя нужно одинаково во всех случаях —
/// раньше новый заказ висел безымянным, пока список не перезагрузится.
Map<String, dynamic> _order(Map<String, dynamic> extra) => {
      'id': '228',
      'order_status': 'published',
      ...extra,
    };

void main() {
  group('OrderDto — имя заказчика', () {
    test('берётся из shop_first_name (загрузка списка)', () {
      final dto = OrderDto.fromMap(_order({
        'shop_first_name': 'Arome',
        'shop_name': 'Arome Kafe',
      }));
      expect(dto.shopFirstName, 'Arome');
    });

    test('берётся из развёрнутой связи shopId (событие WebSocket)', () {
      // Ровно так заказ приезжает по сокету: отдельного поля с именем нет,
      // но связь развёрнута.
      final dto = OrderDto.fromMap(_order({
        'shopId': [
          {
            'item': {'id': 254, 'name': 'Arome', 'surname': 'Kafe'},
          },
        ],
      }));
      expect(dto.shopFirstName, 'Arome');
      expect(dto.shopName, 'Arome Kafe');
    });

    test('падает на первое слово из «Имя Фамилия» (старые данные)', () {
      final dto = OrderDto.fromMap(_order({'shop_name': 'Arome Kafe'}));
      expect(dto.shopFirstName, 'Arome');
    });

    test('неразвёрнутая связь не ломает разбор', () {
      // При обычной загрузке item — это просто идентификатор.
      final dto = OrderDto.fromMap(_order({
        'shop_first_name': 'Arome',
        'shopId': [
          {'item': '254', 'collection': 'customers'},
        ],
      }));
      expect(dto.shopFirstName, 'Arome');
    });

    test('нет ничего — пусто, без падения', () {
      expect(OrderDto.fromMap(_order({})).shopFirstName, '');
      expect(OrderDto.fromMap(_order({'shopId': []})).shopFirstName, '');
      expect(OrderDto.fromMap(_order({'shopId': 'мусор'})).shopFirstName, '');
    });

    test('пустое имя в связи не перебивает готовое значение', () {
      final dto = OrderDto.fromMap(_order({
        'shop_first_name': 'Arome',
        'shopId': [
          {
            'item': {'id': 254, 'name': '', 'surname': ''},
          },
        ],
      }));
      expect(dto.shopFirstName, 'Arome');
    });
  });
}
