import 'package:bagla/features/orders/order_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Уведомление «Новый заказ» уходит всем курьерам сразу, и к моменту тапа
/// заказ часто уже взят другим. Раньше по такому уведомлению курьер
/// проваливался в чужой заказ и видел телефон и адрес клиента.
///
/// Здесь закреплено правило доступа: пускаем создателя, назначенного
/// исполнителя и всех — на ещё свободный заказ. Остальных не пускаем.
Map<String, dynamic> _order({
  String? shopId,
  String? courierId,
  String status = 'published',
}) => {
  'id': 'order-1',
  'order_status': status,
  'shopId': shopId == null
      ? []
      : [
          {'item': shopId, 'collection': 'customers'},
        ],
  'courierId': courierId == null
      ? []
      : [
          {'item': courierId, 'collection': 'customers'},
        ],
};

void main() {
  group('OrderService.canOpenOrder', () {
    test('свободный заказ открыт любому курьеру', () {
      final o = _order(shopId: 'shop-1');
      expect(
        OrderService.canOpenOrder(o, role: 'courier', userId: 'courier-A'),
        isTrue,
      );
    });

    test('заказ, взятый другим курьером, — закрыт', () {
      final o = _order(
        shopId: 'shop-1',
        courierId: 'courier-B',
        status: 'active',
      );
      expect(
        OrderService.canOpenOrder(o, role: 'courier', userId: 'courier-A'),
        isFalse,
      );
    });

    test('свой активный заказ курьер открывает', () {
      final o = _order(
        shopId: 'shop-1',
        courierId: 'courier-A',
        status: 'active',
      );
      expect(
        OrderService.canOpenOrder(o, role: 'courier', userId: 'courier-A'),
        isTrue,
      );
    });

    test('создатель открывает свой заказ на любом статусе', () {
      final o = _order(
        shopId: 'shop-1',
        courierId: 'courier-B',
        status: 'completed',
      );
      expect(
        OrderService.canOpenOrder(o, role: 'shop', userId: 'shop-1'),
        isTrue,
      );
    });

    test('чужой завершённый заказ закрыт', () {
      final o = _order(
        shopId: 'shop-1',
        courierId: 'courier-B',
        status: 'completed',
      );
      expect(
        OrderService.canOpenOrder(o, role: 'shop', userId: 'shop-2'),
        isFalse,
      );
    });

    test('неразвёрнутые связи не блокируют — владельца не определить', () {
      // Fallback `fields: "*"` после 403: Directus отдаёт id связок, а не
      // объекты. Блокировать тут нельзя — отрежем человека от его же заказа.
      final o = {
        'id': 'order-1',
        'order_status': 'active',
        'shopId': [17],
        'courierId': [42],
      };
      expect(
        OrderService.canOpenOrder(o, role: 'courier', userId: 'courier-A'),
        isTrue,
      );
    });

    test('пустой userId не блокирует', () {
      final o = _order(shopId: 'shop-1', courierId: 'courier-B');
      expect(
        OrderService.canOpenOrder(o, role: 'courier', userId: ''),
        isTrue,
      );
    });
  });
}
