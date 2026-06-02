import 'dart:convert';

import 'package:bagla/core/api_client.dart';
import 'package:bagla/core/secure_token_store.dart';
import 'package:bagla/features/notifications/notification_service.dart';
import 'package:bagla/main.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Глобальный флаг: вся one-time инициализация (listeners + initial
  /// message) делается ровно один раз за жизнь процесса.
  /// На повторный вызов `initialize()` (например, после re-auth)
  /// мы НЕ переподписываемся и НЕ обрабатываем initialMessage заново —
  /// иначе после логина другого аккаунта приложение бы кидало на
  /// экран уведомлений (это и был баг).
  bool _initialized = false;

  /// Публичная entry-point: вызывается из верифицирующего auth flow.
  /// Идемпотентна: всю one-time работу делает один раз, а на каждый
  /// логин — обновляет FCM-токен в Directus.
  Future<void> initialize() async {
    if (!_initialized) {
      await _initializeOnce();
      _initialized = true;
    }
    // На каждый логин — синхронизируем токен с текущим user_id в БД,
    // иначе на чужой аккаунт уведомления продолжат идти.
    await _syncTokenToCurrentUser();
  }

  Future<void> _initializeOnce() async {
    // 1. Инициализация локальных уведомлений (foreground)
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@drawable/ic_notification');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      // Tap on a LOCAL notification shown while the app is in the foreground.
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        final data = payload != null
            ? Map<String, dynamic>.from(
                jsonDecode(payload) as Map,
              )
            : <String, dynamic>{};
        _handleNotificationTap(data);
      },
    );

    // 2. Запрос разрешения
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // 3. Обновление токена (например, при переустановке/смене SIM).
    // Этот listener активен на всю жизнь приложения — токен синхронизируется
    // в БД для **текущего** залогиненного пользователя. См. _saveTokenToDirectus.
    _messaging.onTokenRefresh.listen((newToken) {
      _saveTokenToDirectus(newToken);
    });

    // 5. Уведомление когда приложение ОТКРЫТО — показываем локально.
    //    Payload содержит data чтобы тап мог пометить нужное уведомление.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'bagla_channel',
              'Bagla Notifications',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@drawable/ic_notification',
              color: const Color(0xFF1B3A6B),
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          payload: jsonEncode(message.data),
        );
      }
    });

    // 6. Нажатие когда приложение в ФОНЕ
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message.data);
    });

    // 7. Приложение было ЗАКРЫТО — открыли через уведомление.
    // Ждём чтобы auth_token успел загрузиться из prefs (cold-start).
    final RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      Future.delayed(const Duration(seconds: 1), () {
        _handleNotificationTap(initialMessage.data);
      });
    }
  }

  /// Синхронизирует текущий FCM-токен с залогиненным пользователем.
  /// Вызывается на каждый login — гарантирует, что push'ы пойдут
  /// именно на текущий аккаунт, а не на предыдущий.
  Future<void> _syncTokenToCurrentUser() async {
    try {
      final String? token = await _messaging.getToken();
      if (token != null) {
        if (kDebugMode) print('✅ FCM Token sync: $token');
        await _saveTokenToDirectus(token);
      }
    } catch (e) {
      if (kDebugMode) print('❌ FCM sync error: $e');
    }
  }

  /// Опрашивает prefs пока auth_token + user_id не появятся.
  /// Возвращает true если успели за `timeout`, false если так и нет.
  /// Нужно для cold-start: тап на push мог прилететь раньше, чем
  /// AuthProvider.loadUserData успел прочитать prefs.
  Future<bool> _waitForAuth({
    Duration timeout = const Duration(seconds: 5),
    Duration pollEvery = const Duration(milliseconds: 250),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final prefs = await SharedPreferences.getInstance();
      final token = await SecureTokenStore.instance.getAccessToken() ?? '';
      final uid = prefs.getString('user_id') ?? '';
      if (token.isNotEmpty && uid.isNotEmpty) return true;
      await Future.delayed(pollEvery);
    }
    return false;
  }

  Future<void> _saveTokenToDirectus(String fcmToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userId = prefs.getString('user_id');
      // Auth token из secure storage.
      final String? authToken =
          await SecureTokenStore.instance.getAccessToken();

      if (userId == null || userId.isEmpty) {
        if (kDebugMode) {
          print('⚠️ Нет user_id — пропускаем сохранение FCM токена');
        }
        return;
      }

      if (authToken == null || authToken.isEmpty) {
        if (kDebugMode) {
          print('⚠️ Нет auth_token — пропускаем сохранение FCM токена');
        }
        return;
      }

      final ApiClient apiClient = ApiClient();

      // ✅ Правильный путь: /items/customers/{id}
      final response = await apiClient.dio.patch(
        '/items/customers/$userId',
        data: {'fcm_token': fcmToken},
      );

      if (kDebugMode) {
        print('✅ FCM токен сохранён в Directus: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Ошибка сохранения FCM токена: $e');
      }
    }
  }

  void _handleNotificationTap(Map<String, dynamic> data) async {
    final String? notifId = data['notification_id']?.toString();

    // На cold-start auth_token / user_id могут ещё не быть в prefs
    // (AuthProvider.loadUserData асинхронная). Ждём до 5 сек.
    await _waitForAuth();

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';

    // PATCH ОБЯЗАТЕЛЬНО await'им — иначе NotificationsScreen.initState
    // успеет сделать GET до того, как сервер запишет is_read=true.
    // Локальный кэш в NotificationService — двойная подстраховка.
    if (userId.isNotEmpty) {
      if (notifId != null && notifId.isNotEmpty) {
        await NotificationService().markAsRead(notifId);
      } else {
        await NotificationService().markAllAsRead(userId);
      }
    }

    navigatorKey.currentState?.pushNamed('/notifications');
  }
}
