import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:bagla/core/api_client.dart';
import 'package:bagla/core/secure_token_store.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/features/notifications/notification_service.dart';
import 'package:bagla/features/notifications/widgets/notification_helpers.dart';
import 'package:bagla/features/orders/order_detail_screen.dart';
import 'package:bagla/features/orders/order_service.dart';
import 'package:bagla/main.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Глобальный флаг: вся one-time инициализация делается ровно один раз
  bool _initialized = false;

  /// Публичная entry-point: вызывается из верифицирующего auth flow.
  Future<void> initialize() async {
    if (!_initialized) {
      await _initializeOnce();
      _initialized = true;
    }
    // Синхронизируем токен с текущим user_id в БД при каждом логине
    await _syncTokenToCurrentUser();
  }

  Future<void> _initializeOnce() async {
    // 1. Инициализация Awesome Notifications и создание канала
    await AwesomeNotifications().initialize(
      // Small-иконка (статус-бар) — монохромный силуэт ic_notification.
      'resource://drawable/ic_notification',
      [
        NotificationChannel(
          channelKey: 'bagla_channel',
          channelName: 'Bagla Notifications',
          channelDescription: 'Notification channel for Bagla delivery updates',
          defaultColor: const Color(0xFF1B3A6B),
          ledColor: const Color(0xFF1B3A6B),
          importance: NotificationImportance.High,
          playSound: true,
          criticalAlerts: true,
        )
      ],
      debug: kDebugMode,
    );

    // 2. Установка слушателей для тапов по уведомлениям (внутри Awesome)
    await AwesomeNotifications().setListeners(
      onActionReceivedMethod: NotificationController.onActionReceivedMethod,
    );

    // 3. Запрос разрешения у Firebase
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // 4. Обновление токена (активен на всю жизнь приложения)
    _messaging.onTokenRefresh.listen((newToken) {
      _saveTokenToDirectus(newToken);
    });

    // 5. Обработка уведомлений, когда приложение ОТКРЫТО (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: notification.hashCode,
            channelKey: 'bagla_channel',
            title: notification.title,
            body: notification.body,
            // Цветной логотип Bagla справа в уведомлении (#1).
            largeIcon: 'resource://mipmap/launcher_icon',
            // Передаем payload (data) в виде Map<String, String>
            payload: message.data.map((key, value) => MapEntry(key, value.toString())),
          ),
        );
      }
    });

    // 6. Нажатие когда приложение было в ФОНЕ (Firebase fallback)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message.data);
    });

    // 7. Приложение было ЗАКРЫТО (Cold-start)
    final RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      Future.delayed(const Duration(seconds: 1), () {
        _handleNotificationTap(initialMessage.data);
      });
    }
  }

  /// Синхронизирует текущий FCM-токен с залогиненным пользователем.
  Future<void> _syncTokenToCurrentUser() async {
    try {
      final String? token = await _messaging.getToken();
      if (token != null) {
        // ⚠️ НЕ логируем сам FCM-token — это identifier устройства,
        // которым можно отправлять push'и (включая spoofing).
        if (kDebugMode) print('✅ FCM Token sync (len=${token.length})');
        await _saveTokenToDirectus(token);
      }
    } catch (e) {
      if (kDebugMode) print('❌ FCM sync error: $e');
    }
  }

  /// Опрашивает prefs пока auth_token + user_id не появятся.
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
      final String? authToken = await SecureTokenStore.instance.getAccessToken();

      if (userId == null || userId.isEmpty || authToken == null || authToken.isEmpty) {
        return;
      }

      final ApiClient apiClient = ApiClient();
      await apiClient.dio.patch(
        '/items/customers/$userId',
        data: {'fcm_token': fcmToken},
      );

      if (kDebugMode) {
        print('✅ FCM токен сохранён в Directus');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Ошибка сохранения FCM токена: $e');
    }
  }

  /// Маршрутизация и обработка логики прочтения уведомления
  void _handleNotificationTap(Map<String, dynamic> data) async {
    final String? notifId = data['notification_id']?.toString();

    await _waitForAuth();

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';

    if (userId.isNotEmpty) {
      if (notifId != null && notifId.isNotEmpty) {
        await NotificationService().markAsRead(notifId);
      } else {
        await NotificationService().markAllAsRead(userId);
      }
    }

    // #3: если payload содержит id заказа — открываем сам заказ, а не
    // раздел уведомлений.
    final orderId = notifOrderId(data);
    if (orderId != null) {
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        // ctx взят свежим из navigatorKey и read вызывается синхронно —
        // across-async-gap здесь ложноположительный.
        // ignore: use_build_context_synchronously
        final auth = ctx.read<AuthProvider>();
        final order = await OrderService().getOrderById(orderId);
        if (order != null) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen(
                order: order,
                role: auth.role,
                currentUserId: auth.userId,
              ),
            ),
          );
          return;
        }
      }
    }

    navigatorKey.currentState?.pushNamed('/notifications');
  }
}

/// Специфичный для AwesomeNotifications контроллер перехвата событий тапа.
/// Методы ДОЛЖНЫ быть статическими (`@pragma("vm:entry-point")`).
class NotificationController {
  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
    // Вытаскиваем payload и перенаправляем в наш стандартный обработчик тапа
    final Map<String, dynamic> data = receivedAction.payload ?? {};
    PushNotificationService()._handleNotificationTap(data);
  }
}