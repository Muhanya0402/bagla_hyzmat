import 'dart:convert';

import 'package:bagla/core/api_client.dart';
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

  Future<void> initialize() async {
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

    // 3. Получить и сохранить токен
    // 3. Получить и сохранить токен
    try {
      final String? token = await _messaging.getToken();
      if (token != null) {
        if (kDebugMode) {
          print('✅ FCM Token: $token');
        }
        await _saveTokenToDirectus(token);
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Ошибка получения FCM токена:');
        print('Error: $e');
        print('StackTrace: $stackTrace');
      }
    }

    // 4. Обновление токена
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

    // 7. Приложение было ЗАКРЫТО — открыли через уведомление
    final RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      Future.delayed(const Duration(seconds: 1), () {
        _handleNotificationTap(initialMessage.data);
      });
    }
  }

  Future<void> _saveTokenToDirectus(String fcmToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // ✅ Правильные ключи из auth_repository.dart
      final String? userId = prefs.getString('user_id');
      final String? authToken = prefs.getString('auth_token');

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
    // Mark the specific notification as read if its ID is in the payload,
    // otherwise mark all unread — the user is going to the notifications screen.
    final String? notifId = data['notification_id']?.toString();
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';

    if (userId.isNotEmpty) {
      if (notifId != null && notifId.isNotEmpty) {
        NotificationService().markAsRead(notifId);
      } else {
        NotificationService().markAllAsRead(userId);
      }
    }

    navigatorKey.currentState?.pushNamed('/notifications');
  }
}
