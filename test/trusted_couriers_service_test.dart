import 'package:bagla/features/profile/trusted_couriers_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Разбор ответа флоу управления списком надёжных курьеров.
///
/// Коды приходят ТЕЛОМ ответа, а не исключением: проверено на живом сервере
/// 27.08 — текст `throw new Error(...)` из шага флоу наружу не выходит,
/// клиент получает 200 с пустым телом. Поэтому решение принимает шаг
/// `validate`, а ветвление делает операция `condition`.
///
/// Ошибка в разборе превращает понятное «курьер уже в списке» в общее
/// «не удалось» — магазин не поймёт, что делать.
void main() {
  group('TrustedCouriersService.parseOutcome', () {
    test('успех', () {
      expect(
        TrustedCouriersService.parseOutcome({'ok': true, 'id': [7]}),
        TrustedOutcome.ok,
      );
      expect(
        TrustedCouriersService.parseOutcome({'ok': true}),
        TrustedOutcome.ok,
      );
    });

    test('каждый код отказа разбирается в свой исход', () {
      const cases = {
        'ALREADY_ADDED': TrustedOutcome.alreadyAdded,
        'NOT_FOUND': TrustedOutcome.notFound,
        'COURIER_NOT_FOUND': TrustedOutcome.courierUnavailable,
        'COURIER_NOT_ACTIVE': TrustedOutcome.courierUnavailable,
        'NOT_A_SHOP': TrustedOutcome.notAShop,
      };
      cases.forEach((code, want) {
        expect(
          TrustedCouriersService.parseOutcome({'ok': false, 'code': code}),
          want,
          reason: code,
        );
      });
    });

    test('незнакомый код — общая ошибка, а не ложный успех', () {
      expect(
        TrustedCouriersService.parseOutcome({'ok': false, 'code': 'ЧТО_ТО'}),
        TrustedOutcome.error,
      );
      // Главное: `ok:false` никогда не должен читаться как успех.
      expect(
        TrustedCouriersService.parseOutcome({'ok': false}),
        TrustedOutcome.error,
      );
    });

    test('ответ строкой разбирается как JSON', () {
      expect(
        TrustedCouriersService.parseOutcome('{"ok":false,"code":"NOT_FOUND"}'),
        TrustedOutcome.notFound,
      );
      expect(
        TrustedCouriersService.parseOutcome('{"ok":true}'),
        TrustedOutcome.ok,
      );
    });

    test('ответ, завёрнутый в ключ шага, тоже разбирается', () {
      // Directus иногда отдаёт результат вложенным — с этим уже сталкивались
      // соседние вызовы флоу в проекте.
      expect(
        TrustedCouriersService.parseOutcome({
          'respond_err': {'ok': false, 'code': 'ALREADY_ADDED'},
        }),
        TrustedOutcome.alreadyAdded,
      );
      expect(
        TrustedCouriersService.parseOutcome({
          'respond_ok': {'ok': true},
        }),
        TrustedOutcome.ok,
      );
    });

    test('пустое и мусорное тело не выдаются за успех', () {
      expect(TrustedCouriersService.parseOutcome({}), TrustedOutcome.error);
      expect(TrustedCouriersService.parseOutcome(null), TrustedOutcome.error);
      expect(TrustedCouriersService.parseOutcome(''), TrustedOutcome.error);
      expect(
        TrustedCouriersService.parseOutcome('не json'),
        TrustedOutcome.error,
      );
      expect(TrustedCouriersService.parseOutcome(42), TrustedOutcome.error);
    });
  });
}
