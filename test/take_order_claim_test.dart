import 'package:bagla/features/orders/order_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Заказ мог взять второй курьер поверх первого, потому что назначение шло
/// безусловным PATCH'ем. Теперь оно идёт условным bulk-update'ом, и решение
/// «получилось или заказ уже занят» принимается по ответу Directus: массив
/// реально изменённых записей. Пустой массив = фильтр не совпал = заказ занят.
///
/// Эти тесты закрепляют именно ту трактовку, от которой зависит, спишутся ли
/// у курьера жетоны за чужой заказ.
void main() {
  group('OrderService.conditionalUpdateApplied', () {
    test('непустой data — назначение применено', () {
      final body = {
        'data': [
          {'id': 'order-1', 'order_status': 'active'},
        ],
      };
      expect(OrderService.conditionalUpdateApplied(body), isTrue);
    });

    test('пустой data — заказ уже заняли, назначение НЕ применено', () {
      expect(OrderService.conditionalUpdateApplied({'data': []}), isFalse);
    });

    test('ответ без data не считается успехом', () {
      expect(OrderService.conditionalUpdateApplied({'errors': []}), isFalse);
      expect(OrderService.conditionalUpdateApplied(null), isFalse);
      expect(OrderService.conditionalUpdateApplied('ok'), isFalse);
    });

    test('data не-список не считается успехом', () {
      final body = {
        'data': {'id': 'order-1'},
      };
      expect(OrderService.conditionalUpdateApplied(body), isFalse);
    });
  });
}
