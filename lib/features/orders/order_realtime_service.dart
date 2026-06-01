// lib/services/order_realtime_service.dart
//
// Live Query заказов через Directus Realtime (WebSocket).
// Directus 11 поддерживает WebSocket из коробки.
// Документация: https://docs.directus.io/guides/real-time/
//
// Как подключить:
//   1. В docker-compose.yml уже есть Directus 11.6.1 — WebSocket включён.
//   2. Добавь в pubspec.yaml:
//        web_socket_channel: ^2.4.0
//   3. Используй OrderRealtimeService в HomeScreen.

import 'dart:async';
import 'dart:convert';
import 'package:bagla/core/base_url.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

class OrderRealtimeService {
  // ── Настройки ─────────────────────────────────────────────────────────────
  // Замени на свой IP/хост
  static const String _wsPath = '/websocket';

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  bool _connected = false;
  bool _disposed = false;
  String? _authToken;
  String? _subId; // ID подписки — нужен для unsubscribe

  // ── Текущие параметры подключения ────────────────────────────────────────
  // Храним их как поля, чтобы _scheduleReconnect мог использовать тот же
  // набор фильтров без необходимости пробрасывать всё через цепочку колбэков.
  String _role = '';
  String _userId = '';
  bool _myOrdersOnly = false;
  String _transportFilter = 'any';
  String? _shopProvinceId;
  String? _shopEtrapId;
  String? _shopDistrictId;
  String? _deliveryProvinceId;
  String? _deliveryEtrapId;
  String? _deliveryDistrictId;
  String? _shopPhone;
  String? _orderStatus;
  String? _categoryFilter;

  // Колбэки для HomeScreen
  void Function(List<dynamic> orders)? onOrdersUpdate; // начальные данные
  void Function(dynamic order, String event)?
  onOrderEvent; // create/update/delete
  void Function(bool isConnected)? onConnectionChanged;

  // ── Подключение ───────────────────────────────────────────────────────────

  Future<void> connect({
    required String role,
    required String userId,
    bool myOrdersOnly = false,
    String transportFilter = 'any',
    String? shopProvinceId,
    String? shopEtrapId,
    String? shopDistrictId,
    String? deliveryProvinceId,
    String? deliveryEtrapId,
    String? deliveryDistrictId,
    String? shopPhone,
    String? orderStatus,
    String? categoryFilter,
  }) async {
    if (_connected) return;

    // Запоминаем текущий набор параметров — нужны и для reconnect, и для
    // диагностики того, изменились ли фильтры (см. reconnectWithFilters).
    _role = role;
    _userId = userId;
    _myOrdersOnly = myOrdersOnly;
    _transportFilter = transportFilter;
    _shopProvinceId = shopProvinceId;
    _shopEtrapId = shopEtrapId;
    _shopDistrictId = shopDistrictId;
    _deliveryProvinceId = deliveryProvinceId;
    _deliveryEtrapId = deliveryEtrapId;
    _deliveryDistrictId = deliveryDistrictId;
    _shopPhone = shopPhone;
    _orderStatus = orderStatus;
    _categoryFilter = categoryFilter;

    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');

    if (_authToken == null || _authToken!.isEmpty) {
      debugPrint('🔌 WS: нет токена — пропускаем');
      return;
    }

    // Строим фильтр в зависимости от роли — такой же как в getOrders()
    final filter = _buildFilter();

    try {
      final uri = Uri.parse(
        BaseUrl.url
                .replaceFirst('http://', 'ws://')
                .replaceFirst('https://', 'wss://') +
            _wsPath,
      );
      _channel = WebSocketChannel.connect(uri);

      _sub = _channel!.stream.listen(
        (raw) => _onMessage(raw),
        onError: (e) {
          debugPrint('🔌 WS error: $e');
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('🔌 WS closed');
          if (!_disposed) _scheduleReconnect();
        },
        cancelOnError: false,
      );

      // Шаг 1: аутентификация
      _send({'type': 'auth', 'access_token': _authToken});

      // Шаг 2: подписка (отправим после auth в _onMessage)
      _pendingFilter = filter;

      debugPrint('🔌 WS: подключаемся к $uri');
    } catch (e) {
      debugPrint('🔌 WS connect error: $e');
      _scheduleReconnect();
    }
  }

  /// Полный реконнект с новым набором фильтров. Безопасно вызывать
  /// при смене таба или фильтров в модалке — старая подписка закрывается,
  /// новая открывается с актуальными параметрами.
  Future<void> reconnectWithFilters({
    required String role,
    required String userId,
    bool myOrdersOnly = false,
    String transportFilter = 'any',
    String? shopProvinceId,
    String? shopEtrapId,
    String? shopDistrictId,
    String? deliveryProvinceId,
    String? deliveryEtrapId,
    String? deliveryDistrictId,
    String? shopPhone,
    String? orderStatus,
    String? categoryFilter,
  }) async {
    debugPrint('🔌 WS: reconnectWithFilters → закрываем старую подписку');
    await disconnect();
    await connect(
      role: role,
      userId: userId,
      myOrdersOnly: myOrdersOnly,
      transportFilter: transportFilter,
      shopProvinceId: shopProvinceId,
      shopEtrapId: shopEtrapId,
      shopDistrictId: shopDistrictId,
      deliveryProvinceId: deliveryProvinceId,
      deliveryEtrapId: deliveryEtrapId,
      deliveryDistrictId: deliveryDistrictId,
      shopPhone: shopPhone,
      orderStatus: orderStatus,
      categoryFilter: categoryFilter,
    );
  }

  // Временные переменные для подписки после auth
  Map<String, dynamic>? _pendingFilter;

  // ── Обработка сообщений ───────────────────────────────────────────────────

  void _onMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = msg['type'] as String? ?? '';

      switch (type) {
        case 'auth':
          if (msg['status'] == 'ok') {
            _connected = true;
            onConnectionChanged?.call(true);
            debugPrint('🔌 WS: авторизован');
            _subscribe();
            _startPing();
          } else {
            debugPrint('🔌 WS auth failed: ${msg['error']}');
          }
          break;

        case 'subscription':
          final event = msg['event'] as String? ?? '';

          if (event == 'init') {
            // ИГНОРИРУЕМ событие init, чтобы сокеты не затирали данные от HTTP.
            // Первичные данные у нас гарантированно и красиво приходят из getOrders().
            final data = msg['data'] as List<dynamic>? ?? [];
            debugPrint(
              '🔌 WS: Пропущено init-событие для ${data.length} заказов (используется HTTP-кэш)',
            );
          } else if (event == 'create') {
            final data = msg['data'] as List<dynamic>? ?? [];
            for (final order in data) {
              debugPrint('🔌 WS: новый заказ ${order['id']}');
              onOrderEvent?.call(order, 'create');
            }
          } else if (event == 'update') {
            final data = msg['data'] as List<dynamic>? ?? [];
            for (final order in data) {
              debugPrint('🔌 WS: обновлён заказ ${order['id']}');
              onOrderEvent?.call(order, 'update');
            }
          } else if (event == 'delete') {
            final data = msg['data'] as List<dynamic>? ?? [];
            for (final id in data) {
              debugPrint('🔌 WS: удалён заказ $id');
              onOrderEvent?.call({'id': id}, 'delete');
            }
          }
          break;

        case 'ping':
          _send({'type': 'pong'});
          break;

        case 'error':
          debugPrint('🔌 WS error msg: ${msg['error']}');
          break;
      }
    } catch (e) {
      debugPrint('🔌 WS parse error: $e / raw: $raw');
    }
  }

  // ── Подписка на коллекцию orders ─────────────────────────────────────────

  void _subscribe() {
    _subId = 'orders_${DateTime.now().millisecondsSinceEpoch}';

    final payload = <String, dynamic>{
      'type': 'subscribe',
      'collection': 'orders',
      'uid': _subId,
      'query': {
        // Разворачиваем все связанные объекты, иначе фильтры HomeScreen скроют заказы
        'fields': [
          '*',
          'pictures.directus_files_id',
          'district.id',
          'district.district_ru',
          'district.district_tk',
          'etrap.id',
          'etrap.etrap_ru',
          'etrap.etrap_tk',
          'province.id',
          'province.province_ru',
          'province.province_tk',
          'shop_district.id',
          'shop_district.district_ru',
          'shop_district.district_tk',
          'shop_etrap.id',
          'shop_etrap.etrap_ru',
          'shop_etrap.etrap_tk',
          'shop_province.id',
          'shop_province.province_ru',
          'shop_province.province_tk',
          'courierId.*',
        ],
        'sort': ['-date_created'],
        'limit': 100,
        if (_pendingFilter != null && _pendingFilter!.isNotEmpty)
          'filter': _pendingFilter,
      },
    };

    _send(payload);
    debugPrint('🔌 WS: подписка отправлена с глубокими полями uid=$_subId');
  }

  // ── Фильтр (дублирует логику OrderService.getOrders) ─────────────────────

  /// Базовый фильтр по роли + все дополнительные пользовательские фильтры.
  /// Возвращает Directus-совместимый объект для подписки WS.
  ///
  /// Структура: всегда _and-массив `[base, ...extras]`, чтобы серверу было
  /// проще оптимизировать и чтобы добавление новых фильтров было однострочным.
  Map<String, dynamic> _buildFilter() {
    final clauses = <Map<String, dynamic>>[];

    // ── Базовый фильтр по роли (mirrors OrderService.getOrders) ────────────
    if (_role == 'courier') {
      if (_myOrdersOnly) {
        clauses.add({
          'courierId': {
            'item:customers': {
              'id': {'_eq': _userId},
            },
          },
        });
      } else {
        clauses.add({
          'order_status': {
            '_nin': ['completed', 'canceled'],
          },
        });
        clauses.add({
          'courierId': {'_null': true},
        });
      }
    } else if (_role == 'shop' || _role == 'business') {
      clauses.add({
        'shopId': {
          'item:customers': {
            'id': {'_eq': _userId},
          },
        },
      });
    } else {
      clauses.add({
        'courierId': {'_null': true},
      });
      clauses.add({
        'order_status': {
          '_nin': ['completed', 'canceled'],
        },
      });
    }

    // ── Доп. фильтры пользователя (модалка курьера) ────────────────────────
    if (_transportFilter != 'any') {
      clauses.add({
        'transport_type': {'_eq': _transportFilter},
      });
    }
    if (_shopProvinceId != null) {
      clauses.add({
        'shop_province': {'_eq': _shopProvinceId},
      });
    }
    if (_shopEtrapId != null) {
      clauses.add({
        'shop_etrap': {'_eq': _shopEtrapId},
      });
    }
    if (_shopDistrictId != null) {
      clauses.add({
        'shop_district': {'_eq': _shopDistrictId},
      });
    }
    if (_deliveryProvinceId != null) {
      clauses.add({
        'province': {'_eq': _deliveryProvinceId},
      });
    }
    if (_deliveryEtrapId != null) {
      clauses.add({
        'etrap': {'_eq': _deliveryEtrapId},
      });
    }
    if (_deliveryDistrictId != null) {
      clauses.add({
        'district': {'_eq': _deliveryDistrictId},
      });
    }
    if (_shopPhone != null && _shopPhone!.isNotEmpty) {
      clauses.add({
        'shop_phone': {'_eq': _shopPhone},
      });
    }
    if (_orderStatus != null && _orderStatus!.isNotEmpty) {
      clauses.add({
        'order_status': {'_eq': _orderStatus},
      });
    }
    if (_categoryFilter != null && _categoryFilter!.isNotEmpty) {
      clauses.add({
        'category': {'_eq': _categoryFilter},
      });
    }

    return {'_and': clauses};
  }

  // ── Переподключение ───────────────────────────────────────────────────────

  /// Реконнект использует **актуальные** поля сервиса — те, что были заданы
  /// в последнем `connect()` или `reconnectWithFilters()`. Этого достаточно,
  /// потому что мы всегда вызываем эти методы при смене фильтров.
  void _scheduleReconnect() {
    if (_disposed) return;
    _connected = false;
    onConnectionChanged?.call(false);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (_disposed) return;
      debugPrint('🔌 WS: переподключение...');
      connect(
        role: _role,
        userId: _userId,
        myOrdersOnly: _myOrdersOnly,
        transportFilter: _transportFilter,
        shopProvinceId: _shopProvinceId,
        shopEtrapId: _shopEtrapId,
        shopDistrictId: _shopDistrictId,
        deliveryProvinceId: _deliveryProvinceId,
        deliveryEtrapId: _deliveryEtrapId,
        deliveryDistrictId: _deliveryDistrictId,
        shopPhone: _shopPhone,
        orderStatus: _orderStatus,
        categoryFilter: _categoryFilter,
      );
    });
  }

  // ── Пинг каждые 30 сек ────────────────────────────────────────────────────

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_connected) _send({'type': 'ping'});
    });
  }

  // ── Отправка сообщения ────────────────────────────────────────────────────

  void _send(Map<String, dynamic> data) {
    try {
      _channel?.sink.add(jsonEncode(data));
    } catch (e) {
      debugPrint('🔌 WS send error: $e');
    }
  }

  // ── Отключение ────────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    _disposed = true; // ← сначала ставим флаг
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    await _sub?.cancel();
    try {
      await _channel?.sink.close(ws_status.goingAway);
    } catch (_) {}
    _connected = false;
    onConnectionChanged?.call(false);
    _disposed = false; // ← сбрасываем чтобы можно было переподключиться
    debugPrint('🔌 WS: отключён');
  }

  bool get isConnected => _connected;
}
