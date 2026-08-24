import 'package:bagla/core/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

/// Сравнение версий решает, пустить человека в приложение или показать
/// экран обновления. Ошибка здесь отрезает работающих курьеров от заказов,
/// поэтому логика вынесена в чистую функцию и закреплена тестами.
void main() {
  group('AppVersion.isBelow', () {
    test('версия ниже минимальной', () {
      expect(AppVersion.isBelow('1.0.0', '1.2.0'), isTrue);
      expect(AppVersion.isBelow('1.2.0', '1.2.1'), isTrue);
      expect(AppVersion.isBelow('0.9.9', '1.0.0'), isTrue);
    });

    test('версия равна минимальной — пускаем', () {
      expect(AppVersion.isBelow('1.2.0', '1.2.0'), isFalse);
    });

    test('версия выше минимальной — пускаем', () {
      expect(AppVersion.isBelow('1.3.0', '1.2.0'), isFalse);
      expect(AppVersion.isBelow('2.0.0', '1.9.9'), isFalse);
    });

    test('ДВУЗНАЧНЫЕ ЧАСТИ сравниваются как числа, а не как текст', () {
      // Главная ловушка: при сравнении строк '1.10.0' оказалось бы МЕНЬШЕ
      // '1.9.0', потому что символ '1' идёт раньше '9'. Тогда приложение
      // начало бы блокировать тех, у кого версия новее.
      expect(AppVersion.isBelow('1.10.0', '1.9.0'), isFalse);
      expect(AppVersion.isBelow('1.9.0', '1.10.0'), isTrue);
      expect(AppVersion.isBelow('2.0.0', '10.0.0'), isTrue);
    });

    test('пустая минимальная версия = проверка выключена', () {
      expect(AppVersion.isBelow('1.0.0', ''), isFalse);
      expect(AppVersion.isBelow('1.0.0', '   '), isFalse);
    });

    test('пустая текущая версия никого не блокирует', () {
      // Не смогли прочитать свою версию — это наш сбой, а не повод
      // отрезать человека от работы.
      expect(AppVersion.isBelow('', '1.2.0'), isFalse);
    });

    test('разная длина дополняется нулями', () {
      expect(AppVersion.isBelow('1.2', '1.2.0'), isFalse);
      expect(AppVersion.isBelow('1.2', '1.2.1'), isTrue);
      expect(AppVersion.isBelow('1.3', '1.2.9'), isFalse);
    });

    test('номер сборки в сравнении не участвует', () {
      expect(AppVersion.isBelow('1.2.0+7', '1.2.0'), isFalse);
      expect(AppVersion.isBelow('1.2.0+1', '1.2.1'), isTrue);
    });

    test('нечисловые части не ломают сравнение', () {
      expect(AppVersion.isBelow('1.2.0-beta', '1.2.0'), isFalse);
      expect(AppVersion.isBelow('1.0.0-rc1', '1.2.0'), isTrue);
    });
  });
}
