import 'package:bagla/features/orders/order_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrderService.parseReturnResponse', () {
    test('успешный возврат отдаёт остаток отказов', () {
      final (outcome, left) =
          OrderService.parseReturnResponse({'ok': true, 'returns_left': 1});
      expect(outcome, ReturnOutcome.returned);
      expect(left, 1);
    });

    test('чужой заказ', () {
      final (outcome, _) =
          OrderService.parseReturnResponse({'ok': false, 'code': 'NOT_YOUR_ORDER'});
      expect(outcome, ReturnOutcome.notYourOrder);
    });

    test('заказ уже не в работе трактуется как «не ваш»', () {
      final (outcome, _) =
          OrderService.parseReturnResponse({'ok': false, 'code': 'ORDER_NOT_ACTIVE'});
      expect(outcome, ReturnOutcome.notYourOrder);
    });

    test('лимит исчерпан отдаёт ноль остатка', () {
      final (outcome, left) = OrderService.parseReturnResponse(
          {'ok': false, 'code': 'LIMIT_REACHED', 'returns_left': 0});
      expect(outcome, ReturnOutcome.limitReached);
      expect(left, 0);
    });

    test('пустой или непонятный ответ НЕ считается успехом', () {
      expect(OrderService.parseReturnResponse(null).$1, ReturnOutcome.error);
      expect(OrderService.parseReturnResponse({}).$1, ReturnOutcome.error);
      expect(OrderService.parseReturnResponse('ok').$1, ReturnOutcome.error);
      expect(OrderService.parseReturnResponse({'ok': 'true'}).$1, ReturnOutcome.error);
    });

    test('ответ строкой с JSON разбирается', () {
      final (outcome, left) =
          OrderService.parseReturnResponse('{"ok":true,"returns_left":2}');
      expect(outcome, ReturnOutcome.returned);
      expect(left, 2);
    });
  });
}
