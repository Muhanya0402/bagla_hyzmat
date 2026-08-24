import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Делегат центра уведомлений — без него баннер не показывается, пока
    // приложение открыто, и тап по уведомлению не доходит до Flutter.
    // FlutterAppDelegate уже реализует UNUserNotificationCenterDelegate,
    // поэтому достаточно назначить себя.
    UNUserNotificationCenter.current().delegate = self

    // Явно просим APNs-токен. Разрешение на показ уведомлений запрашивает
    // Dart-код (PushNotificationService), но САМА регистрация в APNs —
    // отдельный шаг, и без него FirebaseMessaging.getToken() возвращает
    // null: у Firebase нет APNs-токена, к которому можно привязать FCM.
    // Именно поэтому у iOS-пользователей поле fcm_token в Directus
    // оставалось пустым и пуши не приходили вообще.
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
