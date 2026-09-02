import 'dart:async';

import 'package:flutter/widgets.dart';

/// Одна секундная стрелка на всё приложение.
///
/// В ленте бывает три десятка карточек с обратным отсчётом. Если бы каждая
/// заводила свой `Timer.periodic`, получилось бы тридцать таймеров, которые
/// просыпаются вразнобой и держат процессор. Здесь таймер один, а карточки
/// просто слушают его через `AnimatedBuilder` — тот сам подписывается и
/// отписывается вместе с виджетом.
///
/// Таймер живёт только пока есть слушатели: последняя карточка ушла с экрана —
/// таймер остановлен. Когда приложение уходит в фон, тикер тоже замолкает:
/// кадры всё равно не рисуются, а будить процессор раз в секунду впустую
/// незачем. При возвращении сразу даётся один тик, чтобы время не выглядело
/// застывшим.
class CountdownTicker extends ChangeNotifier {
  static final CountdownTicker instance = CountdownTicker._();

  CountdownTicker._() {
    _lifecycle = AppLifecycleListener(
      onPause: _onPause,
      onResume: _onResume,
    );
  }

  Timer? _timer;
  late final AppLifecycleListener _lifecycle;
  bool _paused = false;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _sync();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _sync();
  }

  void _sync() {
    final needed = hasListeners && !_paused;
    if (needed && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        notifyListeners();
      });
    } else if (!needed && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  void _onPause() {
    _paused = true;
    _sync();
  }

  void _onResume() {
    _paused = false;
    _sync();
    // Один тик сразу: иначе первую секунду после возврата на экране висит
    // время, замершее в момент сворачивания.
    if (hasListeners) notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _lifecycle.dispose();
    super.dispose();
  }
}
