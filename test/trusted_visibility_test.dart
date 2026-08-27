import 'package:bagla/features/orders/order_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Видимость заказов «только для надёжных курьеров».
///
/// Выражение живёт в одном месте и переносится в четыре: REST-лента,
/// живая лента по WebSocket, право Directus №164 и флоу рассылки пушей.
/// Ошибка здесь либо прячет от курьеров нормальные заказы, либо показывает
/// им дорогие заказы чужих магазинов — поэтому закреплено тестами.
void main() {
  group('trustedVisibilityClause', () {
    test('три ветки: NULL, false и своё членство в списке', () {
      final c = OrderService.trustedVisibilityClause('268');
      final branches = c['_or'] as List;

      expect(branches, hasLength(3));
      expect(branches[0], {
        'trusted_only': {'_null': true},
      });
      expect(branches[1], {
        'trusted_only': {'_eq': false},
      });
    });

    test('ВЕТКА NULL обязательна — без неё пропадут все старые заказы', () {
      // Главная ловушка обратной совместимости. У заказов, созданных до
      // появления поля, `trusted_only` равно NULL, а `NULL <> true` в SQL
      // даёт не «истину». Одного условия `_neq: true` хватило бы, чтобы
      // выкинуть из ленты вообще всё, что было создано раньше.
      final branches =
          OrderService.trustedVisibilityClause('1')['_or'] as List;
      final hasNullBranch = branches.any(
        (b) => b is Map && (b['trusted_only'] as Map?)?['_null'] == true,
      );
      expect(hasNullBranch, isTrue);

      final usesNeq = branches.any(
        (b) => b is Map && (b['trusted_only'] as Map?)?.containsKey('_neq') == true,
      );
      expect(usesNeq, isFalse, reason: '_neq: true молча теряет строки с NULL');
    });

    test('id курьера подставляется в путь до списка магазина', () {
      final branches =
          OrderService.trustedVisibilityClause('268')['_or'] as List;
      final membership = branches[2] as Map;

      expect(
        membership['shopId']['item:customers']['trusted_couriers']['courier_id']
            ['id']['_eq'],
        '268',
      );
    });

    test('выражение зависит только от id и не тащит состояние', () {
      final a = OrderService.trustedVisibilityClause('268');
      final b = OrderService.trustedVisibilityClause('268');
      expect(a.toString(), b.toString());
      expect(
        OrderService.trustedVisibilityClause('269').toString(),
        isNot(a.toString()),
      );
    });
  });

  group('flattenFilter', () {
    test('вложенный объект разворачивается в ключи Dio', () {
      final flat = OrderService.flattenFilter(
        OrderService.trustedVisibilityClause('268'),
        prefix: 'filter[_and][0]',
      );

      expect(flat['filter[_and][0][_or][0][trusted_only][_null]'], 'true');
      expect(flat['filter[_and][0][_or][1][trusted_only][_eq]'], 'false');
      expect(
        flat['filter[_and][0][_or][2][shopId][item:customers]'
            '[trusted_couriers][courier_id][id][_eq]'],
        '268',
      );
    });

    test('список скаляров склеивается запятой, как ждёт Directus', () {
      final flat = OrderService.flattenFilter(
        {
          'order_status': {
            '_nin': ['completed', 'canceled'],
          },
        },
        prefix: 'filter',
      );
      expect(flat['filter[order_status][_nin]'], 'completed,canceled');
    });

    test('список объектов разворачивается по индексам', () {
      final flat = OrderService.flattenFilter(
        {
          '_or': [
            {
              'a': {'_eq': 1},
            },
            {
              'b': {'_eq': 2},
            },
          ],
        },
        prefix: 'filter',
      );
      expect(flat['filter[_or][0][a][_eq]'], '1');
      expect(flat['filter[_or][1][b][_eq]'], '2');
    });

    test('обе ленты получают одно и то же выражение', () {
      // REST разворачивает его в плоские ключи, WebSocket берёт как есть.
      // Источник обязан быть один — иначе курьер увидит заказ в ленте и
      // получит отказ при нажатии «Взять».
      final clause = OrderService.trustedVisibilityClause('268');
      final flat = OrderService.flattenFilter(clause, prefix: 'filter[_and][0]');

      expect(flat.keys.where((k) => k.contains('trusted_only')), hasLength(2));
      expect(
        flat.keys.where((k) => k.contains('trusted_couriers')),
        hasLength(1),
      );
    });
  });
}
