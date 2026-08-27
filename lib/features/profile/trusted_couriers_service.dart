import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';

/// Курьер в списке надёжных у магазина.
class TrustedCourier {
  /// Идентификатор строки списка, а не курьера.
  final int rowId;
  final String courierId;
  final String name;
  final String phone;
  final String transportType;
  final String selfieFileId;

  /// Сколько раз возил у этого магазина. Заполняется только у кандидатов.
  final int deliveries;

  const TrustedCourier({
    required this.rowId,
    required this.courierId,
    required this.name,
    this.phone = '',
    this.transportType = '',
    this.selfieFileId = '',
    this.deliveries = 0,
  });
}

/// Чем закончилась попытка изменить список.
enum TrustedOutcome {
  ok,

  /// Курьер уже в списке.
  alreadyAdded,

  /// Курьера нет в списке (при удалении).
  notFound,

  /// Курьер не найден или заблокирован.
  courierUnavailable,

  /// Вызывающий — не магазин. В обычной работе не встречается.
  notAShop,

  /// Сеть или сервер.
  error,
}

/// Список надёжных курьеров магазина.
///
/// **Читаем напрямую, меняем только через флоу.** Права на создание и
/// удаление строк приложению намеренно не выданы: проверено 27.08, что
/// Directus не применяет связанный фильтр к праву `create` — любой
/// пользователь вставлял строку в список чужого магазина и получал доступ
/// к его дорогим заказам. Поэтому магазин определяется на сервере по
/// авторизации, а тело запроса содержит только `courier_id`.
class TrustedCouriersService {
  final ApiClient _apiClient = ApiClient();

  static const _flowAdd = '5ea353a4-0bed-4b99-9092-bf9b54d75a25';
  static const _flowRemove = '2d097a35-294b-438a-ad6d-11be583cf84b';

  /// Разбор ответа флоу. Коды приходят телом, а не исключением: текст
  /// брошенной ошибки Directus наружу не отдаёт (проверено 27.08).
  static TrustedOutcome parseOutcome(dynamic raw) {
    Map<String, dynamic>? body;
    if (raw is Map) {
      body = Map<String, dynamic>.from(raw);
    } else if (raw is String && raw.isNotEmpty) {
      try {
        final d = jsonDecode(raw);
        if (d is Map) body = Map<String, dynamic>.from(d);
      } catch (_) {}
    }
    if (body == null) return TrustedOutcome.error;

    // Directus иногда заворачивает результат в ключ шага — соседи по проекту
    // (`parseReturnResponse`) сталкивались с тем же.
    var r = body;
    if (!r.containsKey('ok') && !r.containsKey('code')) {
      for (final v in body.values) {
        if (v is Map) {
          final nested = Map<String, dynamic>.from(v);
          if (nested.containsKey('ok') || nested.containsKey('code')) {
            r = nested;
            break;
          }
        }
      }
    }

    if (r['ok'] == true) return TrustedOutcome.ok;
    switch ((r['code'] ?? '').toString()) {
      case 'ALREADY_ADDED':
        return TrustedOutcome.alreadyAdded;
      case 'NOT_FOUND':
        return TrustedOutcome.notFound;
      case 'COURIER_NOT_FOUND':
      case 'COURIER_NOT_ACTIVE':
        return TrustedOutcome.courierUnavailable;
      case 'NOT_A_SHOP':
        return TrustedOutcome.notAShop;
      default:
        return TrustedOutcome.error;
    }
  }

  /// Текущий список магазина.
  ///
  /// Фильтр по магазину не нужен: право на чтение уже отдаёт только свои
  /// строки (и строки, где курьер — ты сам).
  Future<List<TrustedCourier>> list(String shopId) async {
    try {
      final res = await _apiClient.dio.get(
        '/items/shop_trusted_couriers',
        queryParameters: {
          'limit': -1,
          'sort': '-date_created',
          'filter[shop_id][_eq]': shopId,
          'fields': 'id,courier_id.id,courier_id.name,courier_id.surname,'
              'courier_id.phone,courier_id.transport_type,courier_id.selfie_scan',
        },
      );
      final data = res.data?['data'];
      if (data is! List) return [];
      return [
        for (final row in data)
          if (row is Map && row['courier_id'] is Map)
            _fromRow(row as Map<String, dynamic>),
      ];
    } catch (e) {
      if (kDebugMode) print('TrustedCouriersService.list: $e');
      return [];
    }
  }

  static TrustedCourier _fromRow(Map<String, dynamic> row) {
    final c = Map<String, dynamic>.from(row['courier_id'] as Map);
    return TrustedCourier(
      rowId: row['id'] is int
          ? row['id'] as int
          : int.tryParse('${row['id']}') ?? 0,
      courierId: '${c['id']}',
      name: _fullName(c),
      phone: '${c['phone'] ?? ''}',
      transportType: '${c['transport_type'] ?? ''}',
      selfieFileId: '${c['selfie_scan'] ?? ''}',
    );
  }

  static String _fullName(Map<String, dynamic> c) {
    final parts = [
      '${c['name'] ?? ''}'.trim(),
      '${c['surname'] ?? ''}'.trim(),
    ].where((s) => s.isNotEmpty);
    return parts.isEmpty ? '' : parts.join(' ');
  }

  /// Курьеры, которые уже возили у этого магазина, — с числом доставок.
  ///
  /// Самый естественный источник: постоянные пары складываются сами, и
  /// магазину не приходится вспоминать имена. Уже добавленные исключаются.
  Future<List<TrustedCourier>> candidatesFromHistory(
    String shopId, {
    Set<String> exclude = const {},
  }) async {
    try {
      final res = await _apiClient.dio.get(
        '/items/orders',
        queryParameters: {
          'limit': -1,
          'filter[shopId][item:customers][id][_eq]': shopId,
          'filter[order_status][_eq]': 'completed',
          'fields': 'id,courierId.item',
        },
      );
      final data = res.data?['data'];
      if (data is! List) return [];

      final counts = <String, int>{};
      for (final o in data) {
        if (o is! Map) continue;
        final cid = _courierIdOf(o);
        if (cid.isEmpty || exclude.contains(cid)) continue;
        counts[cid] = (counts[cid] ?? 0) + 1;
      }
      if (counts.isEmpty) return [];

      final profiles = await _profiles(counts.keys.toList());
      final out = [
        for (final e in counts.entries)
          if (profiles[e.key] != null)
            TrustedCourier(
              rowId: 0,
              courierId: e.key,
              name: _fullName(profiles[e.key]!),
              phone: '${profiles[e.key]!['phone'] ?? ''}',
              transportType: '${profiles[e.key]!['transport_type'] ?? ''}',
              selfieFileId: '${profiles[e.key]!['selfie_scan'] ?? ''}',
              deliveries: e.value,
            ),
      ];
      out.sort((a, b) => b.deliveries.compareTo(a.deliveries));
      return out;
    } catch (e) {
      if (kDebugMode) print('TrustedCouriersService.candidates: $e');
      return [];
    }
  }

  /// `courierId` — связь M2A: `[{item: <id>, collection: customers}]`.
  static String _courierIdOf(Map o) {
    final field = o['courierId'];
    if (field is! List || field.isEmpty) return '';
    final first = field.first;
    if (first is! Map) return '';
    final item = first['item'];
    if (item == null) return '';
    if (item is Map) return '${item['id'] ?? ''}';
    return '$item';
  }

  Future<Map<String, Map<String, dynamic>>> _profiles(List<String> ids) async {
    if (ids.isEmpty) return {};
    final res = await _apiClient.dio.get(
      '/items/customers',
      queryParameters: {
        'limit': -1,
        'filter[id][_in]': ids.join(','),
        'filter[role][_eq]': 'courier',
        'filter[status][_eq]': 'active',
        'fields': 'id,name,surname,phone,transport_type,selfie_scan',
      },
    );
    final data = res.data?['data'];
    if (data is! List) return {};
    return {
      for (final c in data)
        if (c is Map) '${c['id']}': Map<String, dynamic>.from(c),
    };
  }

  Future<TrustedOutcome> add(String courierId) =>
      _callFlow(_flowAdd, courierId);

  Future<TrustedOutcome> remove(String courierId) =>
      _callFlow(_flowRemove, courierId);

  Future<TrustedOutcome> _callFlow(String flowId, String courierId) async {
    try {
      final res = await _apiClient.dio.post(
        '/flows/trigger/$flowId',
        // Магазин НЕ передаётся: сервер берёт его из авторизации.
        data: {'courier_id': int.tryParse(courierId) ?? courierId},
      );
      return parseOutcome(res.data);
    } on DioException catch (e) {
      final parsed = parseOutcome(e.response?.data);
      return parsed == TrustedOutcome.error ? TrustedOutcome.error : parsed;
    } catch (e) {
      if (kDebugMode) print('TrustedCouriersService._callFlow: $e');
      return TrustedOutcome.error;
    }
  }
}
