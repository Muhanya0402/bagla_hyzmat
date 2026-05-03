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
  }) async {
    if (_connected) return;

    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');

    if (_authToken == null || _authToken!.isEmpty) {
      debugPrint('🔌 WS: нет токена — пропускаем');
      return;
    }

    // Строим фильтр в зависимости от роли — такой же как в getOrders()
    final filter = _buildFilter(
      role: role,
      userId: userId,
      myOrdersOnly: myOrdersOnly,
    );

    try {
      final uri = Uri.parse(
        BaseUrl.url
                .replaceFirst('http://', 'ws://')
                .replaceFirst('https://', 'wss://') +
            _wsPath,
      );
      _channel = WebSocketChannel.connect(uri);

      _sub = _channel!.stream.listen(
        (raw) => _onMessage(raw, role, userId, myOrdersOnly),
        onError: (e) {
          debugPrint('🔌 WS error: $e');
          _scheduleReconnect(
            role: role,
            userId: userId,
            myOrdersOnly: myOrdersOnly,
          );
        },
        onDone: () {
          debugPrint('🔌 WS closed');
          if (!_disposed) {
            _scheduleReconnect(
              role: role,
              userId: userId,
              myOrdersOnly: myOrdersOnly,
            );
          }
        },
        cancelOnError: false,
      );

      // Шаг 1: аутентификация
      _send({'type': 'auth', 'access_token': _authToken});

      // Шаг 2: подписка (отправим после auth в _onMessage)
      _pendingFilter = filter;
      _pendingRole = role;
      _pendingUserId = userId;
      _pendingMyOnly = myOrdersOnly;

      debugPrint('🔌 WS: подключаемся к $uri');
    } catch (e) {
      debugPrint('🔌 WS connect error: $e');
      _scheduleReconnect(
        role: role,
        userId: userId,
        myOrdersOnly: myOrdersOnly,
      );
    }
  }

  // Временные переменные для подписки после auth
  Map<String, dynamic>? _pendingFilter;
  String? _pendingRole;
  String? _pendingUserId;
  bool _pendingMyOnly = false;

  // ── Обработка сообщений ───────────────────────────────────────────────────

  void _onMessage(dynamic raw, String role, String userId, bool myOrdersOnly) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = msg['type'] as String? ?? '';

      switch (type) {
        // Авторизация прошла — подписываемся
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

        // Первоначальные данные после подписки
        case 'subscription':
          final event = msg['event'] as String? ?? '';
          if (event == 'init') {
            final data = msg['data'] as List<dynamic>? ?? [];
            debugPrint('🔌 WS: init ${data.length} заказов');
            onOrdersUpdate?.call(data);
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
        'fields': ['*', 'pictures.directus_files_id'],
        'sort': ['-date_created'],
        'limit': 100, // live query — грузим все актуальные
        if (_pendingFilter != null && _pendingFilter!.isNotEmpty)
          'filter': _pendingFilter,
      },
    };

    _send(payload);
    debugPrint('🔌 WS: подписка отправлена uid=$_subId');
  }

  // ── Фильтр (дублирует логику getOrders) ──────────────────────────────────

  Map<String, dynamic> _buildFilter({
    required String role,
    required String userId,
    required bool myOrdersOnly,
  }) {
    if (role == 'courier') {
      if (myOrdersOnly) {
        return {
          'courierId': {
            'item:customers': {
              'id': {'_eq': userId},
            },
          },
        };
      } else {
        return {
          '_and': [
            {
              'order_status': {
                '_nin': ['completed', 'canceled'],
              },
            },
            {
              'courierId': {'_null': true},
            },
          ],
        };
      }
    } else if (role == 'shop' || role == 'business') {
      return {
        'shopId': {
          'item:customers': {
            'id': {'_eq': userId},
          },
        },
      };
    } else {
      return {
        '_and': [
          {
            'courierId': {'_null': true},
          },
          {
            'order_status': {
              '_nin': ['completed', 'canceled'],
            },
          },
        ],
      };
    }
  }

  // ── Переподключение ───────────────────────────────────────────────────────

  void _scheduleReconnect({
    required String role,
    required String userId,
    required bool myOrdersOnly,
  }) {
    if (_disposed) return;
    _connected = false;
    onConnectionChanged?.call(false);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!_disposed) {
        debugPrint('🔌 WS: переподключение...');
        connect(role: role, userId: userId, myOrdersOnly: myOrdersOnly);
      }
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
