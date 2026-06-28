import 'dart:convert';
import 'package:bagla/models/points_rule.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_client.dart';

/// Результат условной отмены заказа [OrderService.cancelOrderIfOpen].
enum CancelOutcome {
  /// Отмена применена (заказ был published/active).
  applied,

  /// Заказ уже терминальный (completed/canceled) — отмена не выполнена.
  alreadyClosed,

  /// Сетевая/серверная ошибка.
  error,
}

class OrderService {
  final ApiClient _apiClient = ApiClient();

  static const int pageSize = 5;

  // ─── 1. СОЗДАНИЕ ЗАКАЗА ───────────────────────────────────────────────────

  Future<bool> createOrder({
    required String address, // адрес доставки (ru)
    required String addresstk, // адрес доставки (tk)
    required String shopAddress, // адрес магазина (ru)
    required String shopAddressTk, // адрес магазина (tk)  ← новый
    required String transportType,
    required String phone,
    required String comment,
    required DateTime? deliveryTime,
    required double itemPrice,
    required double deliveryFee,
    required int pointsAmount,
    required List<XFile> images,
    required String userId,
    required String shopPhone,
    required String? districtId,
    required String? etrapId,
    required String provinceId,
    // ── Локация магазина (откуда забирать) ────────────────────────────────
    required String? shopDistrictId,
    required String? shopEtrapId,
    required String? shopProvinceId,
    // ── Категория магазина (m2o → shop_categories) ────────────────────────
    String? category,
    // ── Несколько товаров на выбор ─────────────────────────────────────────
    bool multipleItems = false,
  }) async {
    try {
      List<String> fileIds = [];
      for (var image in images) {
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            image.path,
            filename: image.name,
          ),
        });
        final resFile = await _apiClient.dio.post('/files', data: formData);
        if (resFile.data?['data'] != null) {
          fileIds.add(resFile.data['data']['id']);
        }
      }

      final double cashbackAmount = (pointsAmount * 0.2).toDouble();

      final orderData = {
        'order_status': 'published',
        'shopId': [
          {'item': userId, 'collection': 'customers'},
        ],

        // ── Адрес магазина (откуда) ────────────────────────────────────────
        'shop_adress': shopAddress,
        'shop_adresstk': shopAddressTk,

        // ── Локация магазина ───────────────────────────────────────────────
        'shop_district': shopDistrictId != null
            ? tryParse(shopDistrictId)
            : null,
        'shop_etrap': shopEtrapId != null ? tryParse(shopEtrapId) : null,
        'shop_province': shopProvinceId != null && shopProvinceId.isNotEmpty
            ? tryParse(shopProvinceId)
            : null,

        'transport_type': transportType,
        'shop_phone': shopPhone,

        // ── Адрес доставки (куда) ──────────────────────────────────────────
        'adress_of_delivery': address,
        'adress_of_deliverytk': addresstk,

        // ── Локация доставки ───────────────────────────────────────────────
        'district': districtId != null ? tryParse(districtId) : null,
        'etrap': etrapId != null ? tryParse(etrapId) : null,
        'province': tryParse(provinceId),

        'client_phone': phone.contains('+993') ? phone : '+993 $phone',
        'comment': comment,
        'time_of_delivery': deliveryTime?.toIso8601String(),
        'delivery_amount': deliveryFee,
        'total_amount': itemPrice + deliveryFee,
        'points_amount': pointsAmount,
        'cashback_amount': cashbackAmount,
        'pictures': fileIds.map((id) => {'directus_files_id': id}).toList(),
        // Категория магазина — slug из shop_categories.
        if (category != null && category.isNotEmpty) 'category': category,
        // Несколько товаров на выбор — отправляем всегда (даже false),
        // чтобы у новых заказов поле было заполнено явно.
        'multiple_items': multipleItems,
      };

      final response = await _apiClient.dio.post(
        '/items/orders',
        data: orderData,
      );
      return response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204;
    } on DioException catch (e) {
      if (e.response != null) {
        if (kDebugMode) print('ОТВЕТ СЕРВЕРА: ${e.response?.data}');
        final errors = e.response?.data['errors'];
        if (errors is List && errors.isNotEmpty) {
          if (kDebugMode) print('ПРИЧИНА: ${errors[0]['message']}');
          if (kDebugMode) print('ДЕТАЛИ: ${errors[0]['extensions']}');
        }
      }
      throw Exception(
        'Не удалось создать заказ: ${e.response?.data?['errors']?[0]?['message'] ?? e.message}',
      );
    } catch (e) {
      if (kDebugMode) print('Неизвестная ошибка createOrder: $e');
      return false;
    }
  }

  int? tryParse(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return int.tryParse(value);
  }

  // ─── 2. ОБНОВЛЕНИЕ СТАТУСА ────────────────────────────────────────────────

  /// Атомарная отмена заказа (CAS / optimistic concurrency).
  ///
  /// Проблема: экран магазина мог показывать УСТАРЕВШИЙ статус (например, при
  /// ошибке соединения realtime не дошёл), поэтому кнопка «Отменить» оставалась
  /// видимой для уже доставленного заказа. Безусловный PATCH перезаписывал
  /// `completed` → `canceled`, ломая целостность (бонусы уже начислены).
  ///
  /// Решение: bulk-update с фильтром `order_status IN (published, active)`.
  /// Это одна атомарная `UPDATE … WHERE` на стороне БД — гонки нет.
  /// Если фильтр не совпал (заказ уже терминальный), Directus вернёт пустой
  /// массив → отмена НЕ применяется.
  Future<CancelOutcome> cancelOrderIfOpen(
    String orderId, {
    required String cancelReason,
    String? shopId,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'order_status': 'canceled',
        'cancel_reason': cancelReason,
      };
      if (shopId != null) data['cancelled_by'] = 'shop';

      final response = await _apiClient.dio.patch(
        '/items/orders',
        data: {
          'query': {
            'filter': {
              'id': {'_eq': orderId},
              'order_status': {
                '_in': ['published', 'active'],
              },
            },
          },
          'data': data,
        },
      );

      final body = response.data;
      final updated = (body is Map) ? body['data'] : null;
      if (updated is List && updated.isNotEmpty) {
        return CancelOutcome.applied;
      }
      // Фильтр не совпал — заказ уже completed/canceled.
      return CancelOutcome.alreadyClosed;
    } catch (e) {
      if (kDebugMode) print('Ошибка cancelOrderIfOpen: $e');
      return CancelOutcome.error;
    }
  }

  Future<bool> updateStatus(
    String orderId,
    String newStatus, {
    String? userId,
    String? courierPhone,
    String? cancelReason,
    String? shopId,
  }) async {
    try {
      final Map<String, dynamic> data = {'order_status': newStatus};
      if (newStatus == 'active' && userId != null) {
        data['courierId'] = [
          {'item': userId, 'collection': 'customers'},
        ];
      }
      if (newStatus == 'canceled' && shopId != null) {
        data['cancelled_by'] = 'shop';
      }
      if (courierPhone != null) data['courier_phone'] = courierPhone;
      if (cancelReason != null) data['cancel_reason'] = cancelReason;

      await _apiClient.dio.patch('/items/orders/$orderId', data: data);
      return true;
    } catch (e) {
      if (kDebugMode) print('Ошибка updateStatus: $e');
      return false;
    }
  }

  // ─── 3. ПОЛУЧЕНИЕ ЗАКАЗОВ С ПАГИНАЦИЕЙ ───────────────────────────────────

  Future<List<dynamic>> getOrders({
    required String role,
    required String userId,
    bool myOrdersOnly = false,
    int offset = 0,
    int limit = pageSize,
    // ── Серверные фильтры ──────────────────────────────────────────
    String? transportFilter,
    String? shopProvinceId,
    String? shopEtrapId,
    String? shopDistrictId,
    String? deliveryProvinceId,
    String? deliveryEtrapId,
    String? deliveryDistrictId,
    String? shopPhone,
    String? orderStatus,
    String? categoryFilter,
    // Несколько статусов сразу (server `_in`). Например, для уведомления
    // магазина — `['published','active']`. Если задан вместе с `orderStatus`,
    // применяются оба фильтра (по сути избыточно — используйте что-то одно).
    List<String>? orderStatusIn,
  }) async {
    try {
      // ⚠️ SECURITY: используем `Map<String, dynamic>` для queryParameters —
      // Dio URL-encod'ит значения. Раньше тут строилась raw URL-строка
      // `filter[shop_phone][_eq]=$shopPhone` → user input (телефон,
      // categoryFilter, ...) попадал в URL без encoding'а → потенциальный
      // filter-injection (атакующий через `&filter[admin][_eq]=true`
      // менял предикаты запроса).
      //
      // Для multi-value ключей с одним именем (несколько `filter[...]`
      // с разными путями ключа) используем разные суффиксы — Dio
      // нормально передаёт их как отдельные query params.
      final Map<String, dynamic> qp = {};

      if (role == 'courier') {
        if (myOrdersOnly) {
          qp['filter[courierId][item:customers][id][_eq]'] = userId;
        } else {
          qp['filter[order_status][_nin]'] = 'completed,canceled';
          qp['filter[courierId][_null]'] = 'true';
        }
      } else if (role == 'shop' || role == 'business') {
        qp['filter[shopId][item:customers][id][_eq]'] = userId;
      } else {
        qp['filter[courierId][_null]'] = 'true';
        qp['filter[order_status][_nin]'] = 'completed,canceled';
      }

      // ── Серверная фильтрация ───────────────────────────────────────
      if (transportFilter != null && transportFilter != 'any') {
        qp['filter[transport_type][_eq]'] = transportFilter;
      }
      if (shopProvinceId != null) qp['filter[shop_province][_eq]'] = shopProvinceId;
      if (shopEtrapId != null) qp['filter[shop_etrap][_eq]'] = shopEtrapId;
      if (shopDistrictId != null) qp['filter[shop_district][_eq]'] = shopDistrictId;
      if (deliveryProvinceId != null) qp['filter[province][_eq]'] = deliveryProvinceId;
      if (deliveryEtrapId != null) qp['filter[etrap][_eq]'] = deliveryEtrapId;
      if (deliveryDistrictId != null) qp['filter[district][_eq]'] = deliveryDistrictId;
      if (shopPhone != null) qp['filter[shop_phone][_eq]'] = shopPhone;
      if (orderStatus != null) qp['filter[order_status][_eq]'] = orderStatus;
      if (orderStatusIn != null && orderStatusIn.isNotEmpty) {
        qp['filter[order_status][_in]'] = orderStatusIn.join(',');
      }
      if (categoryFilter != null && categoryFilter.isNotEmpty) {
        qp['filter[category][_eq]'] = categoryFilter;
      }
      qp['sort'] = '-date_created';
      qp['limit'] = limit;
      qp['offset'] = offset;
      // ─────────────────────────────────────────────────────────────
      // Явный список полей, нужных OrderDto.fromMap. До рефактора
      // запрашивался `*` + 18 expanded полей локации, которые DTO даже
      // не читает — впустую съедали ~60% payload'а.
      //
      // Что НЕ запрашиваем здесь, но нужно на detail-screen:
      //   - pictures (грузим только при открытии заказа)
      //   - district/etrap/province объекты (текст адреса уже в shop_adress/...)
      // Lean explicit field list. Если у Directus role нет прав на одно из
      // этих полей (или relation), он вернёт 403. В этом случае fallback'имся
      // на `*` который возвращает только разрешённые поля.
      // `shop_name` / `shop_title` НЕ запрашиваем — этих колонок на
      // collection `orders` нет (имя магазина живёт на связанном
      // customer'e через `shopId` M2A). Раньше они тут были и Directus
      // мог отдавать 403 за несуществующее поле → fallback на `*` →
      // вся lean-оптимизация (~60% уменьшение payload'а) терялась.
      //
      // Имя подставляется в decorate-цикле ниже: order['shop_name'] =
      // customer.name + customer.surname.
      const leanFields = 'id,order_status,transport_type,'
          'total_amount,delivery_amount,points_amount,cashback_amount,'
          'comment,time_of_delivery,'
          'shop_adress,shop_adresstk,adress_of_delivery,adress_of_deliverytk,'
          'shop_phone,client_phone,courier_phone,'
          'category,multiple_items,'
          'pictures.directus_files_id,'
          // M2A relations — `item` это UUID связанной сущности, `collection`
          // имя коллекции. `shopId` нужен чтобы в decorate-цикле подтянуть
          // имя магазина из customers.
          'courierId.item,courierId.collection,'
          'shopId.item,shopId.collection';

      Response response;
      try {
        response = await _apiClient.dio.get(
          '/items/orders',
          queryParameters: {...qp, 'fields': leanFields},
        );
      } on DioException catch (e) {
        // 403 на lean-fields обычно значит что какое-то поле/relation
        // закрыто permissions в Directus. Retry с `*` (только то, что
        // разрешает access policy).
        if (e.response?.statusCode == 403) {
          if (kDebugMode) {
            print('⚠️ getOrders 403 with lean fields — retrying with *');
          }
          response = await _apiClient.dio.get(
            '/items/orders',
            queryParameters: {...qp, 'fields': '*'},
          );
        } else {
          rethrow;
        }
      }

      if (response.data?['data'] == null) return [];

      final List<dynamic> orders = response.data['data'] as List<dynamic>;

      // Собираем ID курьеров И магазинов в один проход — потом единый
      // batch-fetch по `customers`, чтобы не делать два запроса.
      // Оба поля (`courierId`, `shopId`) — M2A relation, первый элемент
      // — `{item: <uuid>, collection: 'customers'}`.
      String? extractFirstM2AItemId(dynamic field) {
        if (field is! List || field.isEmpty) return null;
        final first = field[0];
        if (first is! Map) return null;
        return first['item']?.toString();
      }

      final Set<String> customerIds = {};
      for (final order in orders) {
        final cid = extractFirstM2AItemId(order['courierId']);
        if (cid != null) customerIds.add(cid);
        final sid = extractFirstM2AItemId(order['shopId']);
        if (sid != null) customerIds.add(sid);
      }

      final Map<String, Map<String, dynamic>> customerMap = {};
      if (customerIds.isNotEmpty) {
        try {
          final resp = await _apiClient.dio.get(
            '/items/customers',
            queryParameters: {
              'filter[id][_in]': customerIds.join(','),
              'fields': 'id,name,surname,selfie_scan',
            },
          );
          final data = resp.data?['data'];
          if (data is List) {
            for (final c in data) {
              final id = c['id']?.toString();
              if (id != null) customerMap[id] = Map<String, dynamic>.from(c);
            }
          }
        } catch (_) {}
      }

      for (final order in orders) {
        // ── Decorate courier_name + selfie ─────────────────────────────
        final courierItemId = extractFirstM2AItemId(order['courierId']);
        if (courierItemId != null && customerMap.containsKey(courierItemId)) {
          final c = customerMap[courierItemId]!;
          order['courier_name'] =
              '${c['name'] ?? ''} ${c['surname'] ?? ''}'.trim();
          final selfie = c['selfie_scan'];
          final selfieId = selfie == null
              ? ''
              : selfie is Map
                  ? (selfie['id']?.toString() ?? '')
                  : selfie.toString();
          if (selfieId.isNotEmpty) {
            order['courier_selfie_file_id'] = selfieId;
          }
        }

        // ── Decorate shop_name из связанного customer'а ────────────────
        // Колонки `shop_name`/`shop_title` на orders нет — имя живёт на
        // customer'e через `shopId` M2A. Подставляем в тот же ключ
        // `shop_name`, чтобы остальной код (OrderDto.shopName,
        // ClassifierCache.mergeFromOrders, фильтр-модалка) читал из
        // привычного места без специальной обработки M2A.
        final shopItemId = extractFirstM2AItemId(order['shopId']);
        if (shopItemId != null && customerMap.containsKey(shopItemId)) {
          final s = customerMap[shopItemId]!;
          final fullName = '${s['name'] ?? ''} ${s['surname'] ?? ''}'.trim();
          if (fullName.isNotEmpty) {
            order['shop_name'] = fullName;
          }
        }
      }

      return orders;
    } on DioException catch (e) {
      // Расширенная диагностика — если 403 повторился даже на `*`,
      // значит у роли вообще нет access policy на `orders`. Покажем
      // полный response сервера — там обычно конкретное объяснение.
      if (kDebugMode) {
        print('❌ getOrders DioException:');
        print('   URL: ${e.requestOptions.uri}');
        print('   Status: ${e.response?.statusCode}');
        print('   Response: ${e.response?.data}');
        print('   Type: ${e.type}');
      }
      // Бросаем дальше — handleRefresh теперь различает error и empty list,
      // не затрёт существующие orders в UI.
      rethrow;
    } catch (e) {
      if (kDebugMode) print('Ошибка getOrders: $e');
      rethrow;
    }
  }

  // ─── 3.4. Один заказ по id (для deep-link из push-уведомления) ────────────

  /// Загружает один заказ по [orderId] и декорирует его так же, как
  /// `getOrders` (подставляет `shop_name` / `courier_name` из связанных
  /// customer'ов через M2A `shopId` / `courierId`).
  ///
  /// Возвращает `Map<String, dynamic>` готовый для `OrderDto.fromMap` и
  /// `OrderDetailScreen(order: ...)`, либо `null` если заказ не найден /
  /// нет доступа / сетевая ошибка. Не бросает — вызывается из обработчика
  /// тапа по уведомлению, где UI не должен падать.
  Future<Map<String, dynamic>?> getOrderById(String orderId) async {
    if (orderId.isEmpty) return null;
    try {
      const fields = 'id,order_status,transport_type,'
          'total_amount,delivery_amount,points_amount,cashback_amount,'
          'comment,time_of_delivery,'
          'shop_adress,shop_adresstk,adress_of_delivery,adress_of_deliverytk,'
          'shop_phone,client_phone,courier_phone,'
          'category,multiple_items,'
          'pictures.directus_files_id,'
          'courierId.item,courierId.collection,'
          'shopId.item,shopId.collection';

      Response response;
      try {
        response = await _apiClient.dio.get(
          '/items/orders/$orderId',
          queryParameters: {'fields': fields},
        );
      } on DioException catch (e) {
        if (e.response?.statusCode == 403) {
          response = await _apiClient.dio.get(
            '/items/orders/$orderId',
            queryParameters: {'fields': '*'},
          );
        } else {
          rethrow;
        }
      }

      final data = response.data?['data'];
      if (data is! Map) return null;
      final order = Map<String, dynamic>.from(data);

      // Decorate shop_name / courier_name (см. getOrders).
      String? firstM2AItemId(dynamic field) {
        if (field is! List || field.isEmpty) return null;
        final first = field[0];
        if (first is! Map) return null;
        return first['item']?.toString();
      }

      final ids = <String>{};
      final cid = firstM2AItemId(order['courierId']);
      if (cid != null) ids.add(cid);
      final sid = firstM2AItemId(order['shopId']);
      if (sid != null) ids.add(sid);

      if (ids.isNotEmpty) {
        try {
          final resp = await _apiClient.dio.get(
            '/items/customers',
            queryParameters: {
              'filter[id][_in]': ids.join(','),
              'fields': 'id,name,surname,selfie_scan',
            },
          );
          final list = resp.data?['data'];
          if (list is List) {
            final map = <String, Map<String, dynamic>>{};
            for (final c in list) {
              final id = c['id']?.toString();
              if (id != null) map[id] = Map<String, dynamic>.from(c);
            }
            if (cid != null && map.containsKey(cid)) {
              final c = map[cid]!;
              order['courier_name'] =
                  '${c['name'] ?? ''} ${c['surname'] ?? ''}'.trim();
              final selfie = c['selfie_scan'];
              final selfieId = selfie == null
                  ? ''
                  : selfie is Map
                      ? (selfie['id']?.toString() ?? '')
                      : selfie.toString();
              if (selfieId.isNotEmpty) order['courier_selfie_file_id'] = selfieId;
            }
            if (sid != null && map.containsKey(sid)) {
              final s = map[sid]!;
              final full = '${s['name'] ?? ''} ${s['surname'] ?? ''}'.trim();
              if (full.isNotEmpty) order['shop_name'] = full;
            }
          }
        } catch (_) {}
      }

      return order;
    } catch (e) {
      if (kDebugMode) print('Ошибка getOrderById: $e');
      return null;
    }
  }

  // ─── 3.5. Картинки заказа (отдельный fetch) ──────────────────────────────

  /// Возвращает `pictures` отдельного заказа в формате
  /// `[{directus_files_id: 'uuid'}, ...]`.
  ///
  /// **Зачем отдельно:** в `getOrders` (список) запрос `pictures.directus_files_id`
  /// иногда падает с 403 из-за permissions на `orders_files` / `directus_files`
  /// для всего списка. Точечный запрос на один заказ обычно работает, потому
  /// что Directus permission rules могут разрешать read одного владельца
  /// заказа но не выборку по списку.
  ///
  /// На 403 / network error возвращает пустой список — детальный экран
  /// просто не покажет картинки. Не блокирует UI.
  Future<List<dynamic>> getOrderPictures(String orderId) async {
    try {
      final res = await _apiClient.dio.get(
        '/items/orders/$orderId',
        queryParameters: {
          'fields': 'pictures.directus_files_id',
        },
      );
      final data = res.data?['data'];
      if (data is Map) {
        final pics = data['pictures'];
        if (pics is List) return pics;
      }
      return [];
    } on DioException catch (e) {
      if (kDebugMode) {
        print('⚠️ getOrderPictures($orderId): '
            '${e.response?.statusCode} ${e.response?.data}');
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ─── 4. КЭШБЕК ───────────────────────────────────────────────────────────

  Future<void> applyCashbackIfOnTime({
    required String orderId,
    required String courierId,
  }) async {
    try {
      final orderResp = await _apiClient.dio.get(
        '/items/orders/$orderId',
        queryParameters: {
          'fields': 'cashback_amount,time_of_delivery,courierId',
        },
      );
      final order = orderResp.data['data'];
      final double cashback = (order['cashback_amount'] ?? 0.0).toDouble();
      if (cashback <= 0) return;

      final String? tod = order['time_of_delivery'];
      bool isOnTime = true;
      if (tod != null && tod.isNotEmpty) {
        isOnTime = DateTime.now().isBefore(DateTime.parse(tod).toLocal());
      }
      if (!isOnTime) {
        if (kDebugMode) print('⏰ Просрочен — кэшбек не начислен');
        return;
      }

      final courierResp = await _apiClient.dio.get(
        '/items/customers/$courierId',
        queryParameters: {'fields': 'balance_points'},
      );
      final int current =
          (courierResp.data['data']['balance_points'] ?? 0) as int;
      await _apiClient.dio.patch(
        '/items/customers/$courierId',
        data: {'balance_points': current + cashback.toInt()},
      );
      if (kDebugMode) {
        print('✅ Кэшбек +${cashback.toInt()} → курьер $courierId');
      }
    } catch (e) {
      if (kDebugMode) print('Ошибка applyCashback: $e');
    }
  }

  // ─── 5. ГЕНЕРАЦИЯ КОДА ДОСТАВКИ ──────────────────────────────────────────

  Map<String, dynamic> _parseFlow(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.isNotEmpty) {
      try {
        final d = jsonDecode(raw);
        if (d is Map) return Map<String, dynamic>.from(d);
      } catch (_) {}
    }
    return {};
  }

  Future<Map<String, dynamic>> generateDeliveryCode({
    required String orderId,
    required String courierId,
    required String clientPhone,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/flows/trigger/64ece654-d07e-4ff4-a34c-f50d736a3b32',
        data: {
          'order_id': orderId,
          'courier_id': courierId,
          'client_phone': clientPhone,
        },
      );
      final data = _parseFlow(response.data);
      // ⚠️ НЕ логируем `data` — содержит delivery_code (SMS-OTP клиента).
      if (kDebugMode) print('generateDeliveryCode: ok');

      if (data['delivery_code'] != null) {
        return {'success': true, 'code': data['delivery_code'].toString()};
      }
      for (final v in data.values) {
        if (v is Map && v['delivery_code'] != null) {
          return {'success': true, 'code': v['delivery_code'].toString()};
        }
      }
      return {'success': false};
    } catch (e) {
      if (kDebugMode) print('Ошибка generateDeliveryCode: $e');
      return {'success': false};
    }
  }

  // ─── 6. ВЕРИФИКАЦИЯ КОДА ДОСТАВКИ ────────────────────────────────────────

  Future<Map<String, dynamic>> verifyDeliveryCode({
    required String orderId,
    required String code,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/flows/trigger/6074ab32-630b-406b-9cb5-936c33f8bc42',
        data: {'order_id': orderId, 'code': code},
      );
      final data = _parseFlow(response.data);
      // ⚠️ НЕ логируем `data` — содержит код доставки.
      if (kDebugMode) print('verifyDeliveryCode: ok');

      Map<String, dynamic>? found;
      if (data['success'] != null) {
        found = data;
      } else {
        for (final v in data.values) {
          if (v is Map && v['success'] != null) {
            found = Map<String, dynamic>.from(v);
            break;
          }
        }
      }

      if (found != null) {
        return {
          'success': found['success'] == 'yes' || found['success'] == true,
          'message': found['message'] ?? '',
          'xp_earned': found['xp_earned'] ?? 0,
          'level_up': found['level_up'] ?? false,
        };
      }
      return {
        'success': false,
        'message': 'Ошибка',
        'xp_earned': 0,
        'level_up': false,
      };
    } catch (e) {
      if (kDebugMode) print('Ошибка verifyDeliveryCode: $e');
      return {
        'success': false,
        'message': 'Ошибка сети',
        'xp_earned': 0,
        'level_up': false,
      };
    }
  }

  // ─── 7. КОЛИЧЕСТВО АКТИВНЫХ ЗАКАЗОВ КУРЬЕРА ──────────────────────────────

  Future<int> getActiveOrdersCount(String courierId) async {
    try {
      final response = await _apiClient.dio.get(
        '/items/orders',
        queryParameters: {
          'filter[courierId][item:customers][id][_eq]': courierId,
          'filter[order_status][_eq]': 'active',
          'aggregate[count]': 'id',
        },
      );
      final data = response.data?['data'];
      if (data is List && data.isNotEmpty) {
        return int.tryParse(data[0]['count']?['id']?.toString() ?? '0') ?? 0;
      }
      return 0;
    } catch (e) {
      if (kDebugMode) print('Ошибка getActiveOrdersCount: $e');
      return 0;
    }
  }

  /// Полный список активных заказов пользователя — НЕЗАВИСИМО от пагинации
  /// ленты на главной. Нужен для persistent-уведомления «Активные заказы»:
  /// иначе оно строилось из загруженной страницы `orders` и при 10 активных,
  /// но 6 подгруженных, показывало «из 6».
  ///
  ///   - курьер → его заказы в статусе `active` (макс. 3 по бизнес-правилу);
  ///   - магазин → его заказы в статусах `published` + `active`;
  ///   - клиент → уведомления нет, пустой список.
  ///
  /// Лимит 100 — заведомо выше любого реалистичного числа активных заказов.
  Future<List<dynamic>> getActiveOrders({
    required String role,
    required String userId,
  }) async {
    if (userId.isEmpty) return const [];
    if (role == 'courier') {
      return getOrders(
        role: 'courier',
        userId: userId,
        myOrdersOnly: true,
        orderStatusIn: const ['active'],
        limit: 100,
      );
    }
    if (role == 'shop' || role == 'business') {
      return getOrders(
        role: role,
        userId: userId,
        orderStatusIn: const ['published', 'active'],
        limit: 100,
      );
    }
    return const [];
  }

  // ─── 8. ПРАВИЛА НАЧИСЛЕНИЯ БАЛЛОВ ────────────────────────────────────────

  Future<List<PointsRule>> fetchPointsRules() async {
    try {
      final response = await _apiClient.dio.get(
        '/items/points_rules',
        queryParameters: {'sort': '-min_amount'},
      );
      final List data = response.data['data'] as List;
      return data.map((e) => PointsRule.fromJson(e)).toList();
    } catch (e) {
      if (kDebugMode) print('Ошибка fetchPointsRules: $e');
      // fallback — старая логика, если Directus недоступен
      return [
        PointsRule(minAmount: 2000, points: 5),
        PointsRule(minAmount: 1000, points: 4),
        PointsRule(minAmount: 500, points: 3),
        PointsRule(minAmount: 100, points: 2),
        PointsRule(minAmount: 0, points: 0),
      ];
    }
  }

  int calculatePoints(double orderSum, List<PointsRule> rules) {
    for (final rule in rules) {
      if (orderSum >= rule.minAmount) return rule.points;
    }
    return 0;
  }
}
