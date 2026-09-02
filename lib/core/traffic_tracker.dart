import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Учёт израсходованного трафика — по дням и по разделам приложения.
///
/// Считается обмен с сервером, который идёт через [ApiClient]: списки заказов,
/// профиль, уведомления, загрузка фотографий на сервер. Не попадают сюда две
/// вещи: показ уже загруженных фотографий (их тянет системный загрузчик
/// картинок, мимо нашего клиента) и живое подключение для обновлений в
/// реальном времени. Об этом честно сказано на экране — лучше показать
/// неполную, но правдивую цифру, чем правдоподобную выдумку.
///
/// Данные лежат в SharedPreferences и никуда не отправляются: это личная
/// статистика на устройстве.
class TrafficTracker {
  static final TrafficTracker _instance = TrafficTracker._();
  factory TrafficTracker() => _instance;
  TrafficTracker._();

  static const _key = 'traffic_stats_v1';

  /// Сколько дней храним подробную разбивку. Дальше — только общий итог.
  static const int keepDays = 30;

  TrafficStats _stats = TrafficStats.empty();
  bool _loaded = false;
  Timer? _flushDebounce;

  /// Экран статистики подписывается, чтобы обновляться на лету.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  Future<TrafficStats> load() async {
    if (_loaded) return _stats;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        _stats = TrafficStats.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      // Битая запись не должна ронять приложение — начинаем с чистого листа.
      _stats = TrafficStats.empty();
    }
    _loaded = true;
    return _stats;
  }

  /// Записать один обмен с сервером.
  ///
  /// Вызывается из перехватчика на каждый ответ, в том числе на ошибочный:
  /// неудачный запрос тратит трафик ровно так же, как удачный.
  void record({required String path, required int sent, required int received}) {
    if (sent <= 0 && received <= 0) return;
    // Загрузку из хранилища не ждём: до её конца копим в памяти, а слияние
    // произойдёт при первом сохранении.
    unawaited(_recordAsync(path: path, sent: sent, received: received));
  }

  Future<void> _recordAsync({
    required String path,
    required int sent,
    required int received,
  }) async {
    await load();
    final day = _today();
    final total = sent + received;

    final d = _stats.days.putIfAbsent(day, () => DayTraffic.empty());
    d.sent += sent;
    d.received += received;

    final cat = categoryOf(path);
    _stats.byCategory[cat] = (_stats.byCategory[cat] ?? 0) + total;

    final op = _operationOf(path);
    _stats.byOperation[op] = (_stats.byOperation[op] ?? 0) + total;

    _stats.totalSent += sent;
    _stats.totalReceived += received;
    _stats.requests += 1;
    _stats.since ??= DateTime.now();

    _trim();
    revision.value++;
    _scheduleFlush();
  }

  /// Старые дни выкидываем: экран показывает две недели, хранить год незачем.
  /// Общий итог при этом не теряется — он копится отдельными счётчиками.
  void _trim() {
    if (_stats.days.length <= keepDays) return;
    final keys = _stats.days.keys.toList()..sort();
    for (final k in keys.take(_stats.days.length - keepDays)) {
      _stats.days.remove(k);
    }
  }

  void _scheduleFlush() {
    _flushDebounce?.cancel();
    _flushDebounce = Timer(const Duration(seconds: 3), flush);
  }

  Future<void> flush() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(_stats.toJson()));
    } catch (_) {
      // Не смогли сохранить — статистика останется в памяти до следующего раза.
    }
  }

  Future<void> reset() async {
    _stats = TrafficStats.empty();
    _loaded = true;
    revision.value++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }

  TrafficStats get stats => _stats;

  static String _today() => _dayKey(DateTime.now());

  static String _dayKey(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';

  /// Раздел приложения по адресу запроса — для разбивки «на что ушло».
  static String categoryOf(String path) {
    final p = path.toLowerCase();
    if (p.contains('/assets') || p.contains('/files')) return 'photos';
    if (p.contains('/items/orders')) return 'orders';
    if (p.contains('/items/notifications')) return 'notifications';
    if (p.contains('/items/customers') || p.contains('/users')) return 'profile';
    if (p.contains('/auth') || p.contains('otp')) return 'auth';
    return 'other';
  }

  /// Адрес без идентификаторов — чтобы «тяжёлые» запросы группировались,
  /// а не рассыпались по одному на каждый заказ.
  static String _operationOf(String path) {
    final cleaned = path.split('?').first;
    final parts = cleaned.split('/').where((s) => s.isNotEmpty).map((s) {
      final isId = RegExp(r'^\d+$').hasMatch(s) ||
          RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}').hasMatch(s);
      return isId ? ':id' : s;
    });
    return '/${parts.join('/')}';
  }
}

/// Трафик за один день.
class DayTraffic {
  int sent;
  int received;
  DayTraffic({required this.sent, required this.received});
  factory DayTraffic.empty() => DayTraffic(sent: 0, received: 0);

  int get total => sent + received;

  Map<String, dynamic> toJson() => {'s': sent, 'r': received};
  factory DayTraffic.fromJson(Map<String, dynamic> j) => DayTraffic(
        sent: (j['s'] as num?)?.toInt() ?? 0,
        received: (j['r'] as num?)?.toInt() ?? 0,
      );
}

/// Вся накопленная статистика.
class TrafficStats {
  final Map<String, DayTraffic> days;
  final Map<String, int> byCategory;
  final Map<String, int> byOperation;
  int totalSent;
  int totalReceived;
  int requests;
  DateTime? since;

  TrafficStats({
    required this.days,
    required this.byCategory,
    required this.byOperation,
    required this.totalSent,
    required this.totalReceived,
    required this.requests,
    required this.since,
  });

  factory TrafficStats.empty() => TrafficStats(
        days: {},
        byCategory: {},
        byOperation: {},
        totalSent: 0,
        totalReceived: 0,
        requests: 0,
        since: null,
      );

  int get total => totalSent + totalReceived;

  int get today => days[TrafficTracker._today()]?.total ?? 0;

  /// Среднее за сутки по дням, когда приложением реально пользовались.
  /// Делить на календарные дни было бы нечестно: простой занижает цифру.
  int get averagePerActiveDay {
    if (days.isEmpty) return 0;
    final sum = days.values.fold<int>(0, (a, d) => a + d.total);
    return sum ~/ days.length;
  }

  /// Прикидка на месяц по среднему за активные сутки.
  int get monthlyForecast => averagePerActiveDay * 30;

  /// Последние [n] дней подряд, включая дни без трафика — иначе на графике
  /// пропуски схлопываются и картина выглядит ровнее, чем есть.
  List<MapEntry<DateTime, int>> lastDays(int n) {
    final now = DateTime.now();
    return List.generate(n, (i) {
      final d = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: n - 1 - i));
      return MapEntry(d, days[TrafficTracker._dayKey(d)]?.total ?? 0);
    });
  }

  Map<String, dynamic> toJson() => {
        'days': days.map((k, v) => MapEntry(k, v.toJson())),
        'cats': byCategory,
        'ops': byOperation,
        'ts': totalSent,
        'tr': totalReceived,
        'n': requests,
        'since': since?.toIso8601String(),
      };

  factory TrafficStats.fromJson(Map<String, dynamic> j) {
    final rawDays = (j['days'] as Map?) ?? {};
    final rawCats = (j['cats'] as Map?) ?? {};
    final rawOps = (j['ops'] as Map?) ?? {};
    return TrafficStats(
      days: rawDays.map((k, v) => MapEntry(
            k.toString(),
            DayTraffic.fromJson(Map<String, dynamic>.from(v as Map)),
          )),
      byCategory: rawCats.map((k, v) =>
          MapEntry(k.toString(), (v as num).toInt())),
      byOperation: rawOps.map((k, v) =>
          MapEntry(k.toString(), (v as num).toInt())),
      totalSent: (j['ts'] as num?)?.toInt() ?? 0,
      totalReceived: (j['tr'] as num?)?.toInt() ?? 0,
      requests: (j['n'] as num?)?.toInt() ?? 0,
      since: j['since'] != null ? DateTime.tryParse(j['since'].toString()) : null,
    );
  }
}

/// Байты в понятную строку: 1.2 МБ, 340 КБ, 0 Б.
String formatBytes(int bytes, {required bool isRu}) {
  final kb = isRu ? 'КБ' : 'KB';
  final mb = isRu ? 'МБ' : 'MB';
  final b = isRu ? 'Б' : 'B';
  if (bytes < 1024) return '$bytes $b';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} $kb';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} $mb';
}
