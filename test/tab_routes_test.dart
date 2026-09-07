import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Каждая вкладка в MainShell живёт со своим навигатором, и нажатие в меню
/// профиля ловит именно он, а не корневой. Маршрут, прописанный только в
/// `main.dart`, отсюда недостижим: кнопка молча ничего не делает, без ошибки
/// и без единой строчки в журнале.
///
/// На эти грабли наступали дважды — «Приведи друга» с «Надёжными курьерами»
/// и потом «Анализ трафика». Проверка сверяет исходники напрямую: куда ведут
/// кнопки профиля и что умеет открывать вкладочный навигатор.
void main() {
  test('вкладочный навигатор знает все маршруты из меню профиля', () {
    final profile =
        File('lib/features/profile/profile_screen.dart').readAsStringSync();
    final shell =
        File('lib/features/shell/main_shell.dart').readAsStringSync();

    final targets = RegExp(r"pushNamed\(\s*context\s*,\s*'([^']+)'")
        .allMatches(profile)
        .map((m) => m.group(1)!)
        .toSet();

    final handled = RegExp(r"name == '([^']+)'")
        .allMatches(shell)
        .map((m) => m.group(1)!)
        .toSet();

    expect(targets, isNotEmpty,
        reason: 'не нашлось ни одного перехода из меню профиля — '
            'изменился способ навигации, проверку надо обновить');

    final missing = targets.difference(handled);
    expect(
      missing,
      isEmpty,
      reason: 'эти экраны открываются из профиля, но вкладочный навигатор '
          'о них не знает — кнопки будут молчать: ${missing.join(', ')}. '
          'Добавьте их в _tabRoute в main_shell.dart',
    );
  });
}
