import 'package:bagla/core/app_settings_provider.dart';
import 'package:bagla/core/app_version.dart';
import 'package:bagla/core/widgets/update_required_screen.dart';
import 'package:bagla/core/splash_screen.dart';
import 'package:bagla/core/theme/app_theme.dart';
import 'package:bagla/core/theme/theme_provider.dart';
import 'package:bagla/core/tour/tour_manager.dart';
import 'package:bagla/features/appeals/appeals_screen.dart';
import 'package:bagla/features/shell/main_shell.dart';
import 'package:bagla/features/profile/referrals_screen.dart';
import 'package:bagla/features/profile/trusted_couriers_screen.dart';
import 'package:bagla/features/profile/terms_screen.dart';
import 'package:bagla/features/profile/traffic_screen.dart';
import 'package:bagla/features/profile/user_type_selection_screen.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/features/levels/level_provider.dart';
import 'package:bagla/providers/role_provider.dart';
import 'package:bagla/features/notifications/push_notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui' show DartPluginRegistrant;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/api_client.dart';
import 'core/secure_token_store.dart';
import 'features/notifications/active_orders/active_orders_notification.dart';
import 'features/notifications/active_orders/active_orders_sync.dart';
import 'features/profile/registration_details_screen.dart';
import 'features/profile/transactions/transaction_history_screen.dart';
import 'features/profile/registration_fix_screen.dart';
import 'l10n/language_provider.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/phone_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Глобальный ScaffoldMessenger — нужен чтобы показывать SnackBar'ы
/// из мест без BuildContext (например, ApiClient при истёкшем refresh-token).
/// Привязывается к корню MaterialApp, переживает route changes.
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // ⚠️ ОБЯЗАТЕЛЬНО первой строкой. firebase_messaging НЕ вызывает
  // DartPluginRegistrant для фонового isolate, а shared_preferences_android
  // регистрируется именно на стороне Dart (`dartPluginClass`). Без этого
  // `SharedPreferences.getInstance()` внутри runFromPrefs падает, и
  // persistent-уведомление «Активные заказы» не пересобиралось: у заказчика
  // завершённый курьером заказ висел активным, пока он не откроет приложение.
  DartPluginRegistrant.ensureInitialized();

  // ⚠️ Фоновому isolate ЗАПРЕЩЕНО обновлять токены. Refresh-токен Directus
  // одноразовый; ротация из фона (плюс убийство процесса MIUI посреди
  // refresh, до записи новой пары) оставляла в хранилище погашенный токен —
  // и основной isolate спустя минуты выкидывал пользователя на экран входа.
  // Здесь работаем только на живом access-токене: протух — просто выходим,
  // шторку обновит основной isolate при следующем событии.
  ApiClient.tokenRefreshDisabled = true;

  // Firebase уже инициализирован в main(), повторный вызов не нужен.
  // Не логируем messageId — это корреляция с пользователем.
  if (kDebugMode) print('Фоновое сообщение получено');

  // Если пуш про заказ (создание/смена статуса) — пересобираем persistent
  // уведомление «Активные заказы» прямо из background isolate. Иначе у
  // заказчика число активных заказов «зависало» в шторке, пока он не
  // откроет приложение (в фоне WebSocket отключён, и пересчёта не было).
  final type = (message.data['type'] ?? '').toString();
  final orderId = (message.data['order_id'] ?? '').toString();
  final orderStatus = (message.data['order_status'] ?? '').toString();
  if (orderId.isEmpty && !type.contains('order')) return;

  // ── Быстрый путь: заказ закрыт → снимаем его со шторки локально ─────────
  // Без сети. MIUI даёт процессу на обработку пуша около трёх секунд
  // (logcat: `idle->background(3109ms)` → `background->idle(3001ms)`), а
  // сетевой пересчёт ниже на медленном Directus в этот бюджет не влезает.
  // Из-за этого у заказчика завершённый курьером заказ висел активным, пока
  // тот не откроет приложение. Локальное удаление успевает всегда.
  // `order_status` кладёт в data флоу «Уведомление - Изменение статуса
  // заказа»; если его нет (старая версия флоу) — просто идём дальше.
  const terminalStatuses = {'completed', 'canceled', 'cancelled', 'closed'};
  if (orderId.isNotEmpty && terminalStatuses.contains(orderStatus)) {
    try {
      await ActiveOrdersNotification.removeOrder(orderId);
    } catch (e) {
      if (kDebugMode) print('Не удалось снять заказ со шторки: $e');
    }
  }

  // ── Полный пересчёт — по возможности ───────────────────────────────────
  // Уточняет картину (новые заказы, смена адреса). Если система усыпит
  // процесс раньше, чем придёт ответ сервера, быстрый путь выше уже
  // отработал.
  try {
    await ActiveOrdersSync.runFromPrefs();
  } catch (e) {
    // best-effort, но в debug причину показываем: молчаливый catch уже
    // однажды спрятал именно этот сбой.
    if (kDebugMode) print('ActiveOrdersSync (фон) не отработал: $e');
  }
}

// ── Entry point ───────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase инициализируется ПЕРВЫМ — до runApp, до любых сервисов
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const AppBootstrap());
}

// ── Bootstrap widget ──────────────────────────────────────────────────────────

class _AppData {
  final LanguageProvider langProvider;
  final ThemeProvider themeProvider;
  final bool loggedIn;
  final bool needsRoleSelection;

  const _AppData({
    required this.langProvider,
    required this.themeProvider,
    required this.loggedIn,
    required this.needsRoleSelection,
  });
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  _AppData? _data;

  /// All async initialisation. Runs while SplashScreen plays.
  Future<void> _initialize(VoidCallback onSplashDone) async {
    await initializeDateFormatting('ru', null);

    // Своя версия нужна до первого экрана: по ней решается, пускать ли
    // человека дальше, и она же уходит в профиль вместе с FCM-токеном.
    await AppVersion.load();

    // Firebase и onBackgroundMessage уже зарегистрированы в main()

    final langProvider = LanguageProvider();
    await langProvider.loadSavedLanguage();

    final prefs = await SharedPreferences.getInstance();
    final themeProvider = ThemeProvider.fromPrefs(prefs);

    // Одноразовая миграция auth/refresh токенов из plain SharedPreferences
    // в secure storage (Keychain/Keystore). ОБЯЗАТЕЛЬНО до первой API-сессии,
    // потому что ApiClient interceptor читает токен из secure store.
    await SecureTokenStore.instance.migrateFromPrefsIfNeeded();

    // Привязываем session-expired toast к глобальному ScaffoldMessenger.
    // ApiClient вызовет это когда refresh-token протух → пользователь
    // окажется на /login и увидит объяснение, а не silent kick.
    ApiClient().onSessionExpired = () {
      final messenger = scaffoldMessengerKey.currentState;
      if (messenger == null) return;
      final words = langProvider.words;
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                words.sessionExpiredTitle,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                words.sessionExpiredBody,
                style: const TextStyle(fontSize: 12.5),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    };

    await TourManager.instance.init();

    // Persistent notification «Активные заказы» — канал + listeners один раз
    // за процесс. Title/desc берём из текущего языка (если поменяется на лету,
    // канал останется с прежним именем — это допустимо, имена видны только
    // в системных настройках Android).
    await ActiveOrdersNotification.initialize(
      channelName: langProvider.words.activeOrdersChannelName,
      channelDesc: langProvider.words.activeOrdersChannelDesc,
    );

    final bool loggedIn = await AuthRepository.checkAuthStatus();
    final String savedRole = prefs.getString('role') ?? '';
    final bool needsRoleSelection = loggedIn && savedRole.isEmpty;

    if (loggedIn) {
      await PushNotificationService().initialize();
    }

    final data = _AppData(
      langProvider: langProvider,
      themeProvider: themeProvider,
      loggedIn: loggedIn,
      needsRoleSelection: needsRoleSelection,
    );

    // Trigger SplashScreen exit animation, then switch to the full app.
    onSplashDone();
    await Future.delayed(const Duration(milliseconds: 400)); // fade-out time
    if (mounted) setState(() => _data = data);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;

    // ── Splash phase ─────────────────────────────────────────────────────────
    if (data == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        home: SplashScreen(onReady: _initialize),
      );
    }

    // ── App phase ────────────────────────────────────────────────────────────
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RoleProvider()),
        ChangeNotifierProvider(create: (_) => LevelProvider()),
        // `..load()` — иначе настройки читались только при свайпе в профиле,
        // и до первого захода туда приложение считало пополнение жетонов
        // включённым, даже если администратор его выключил.
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()..load()),
        ChangeNotifierProvider.value(value: data.langProvider),
        ChangeNotifierProvider.value(value: data.themeProvider),
      ],
      child: MyApp(
        isLoggedIn: data.loggedIn,
        needsRoleSelection: data.needsRoleSelection,
      ),
    );
  }
}

// ── Main app ──────────────────────────────────────────────────────────────────

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final bool needsRoleSelection;

  const MyApp({
    super.key,
    required this.isLoggedIn,
    required this.needsRoleSelection,
  });

  @override
  Widget build(BuildContext context) {
    Widget home;
    if (!isLoggedIn) {
      home = const PhoneScreen();
    } else if (needsRoleSelection) {
      home = const UserTypeSelectionScreen();
    } else {
      home = const MainShell();
    }

    final themeMode = context.watch<ThemeProvider>().themeMode;
    final settings = context.watch<AppSettingsProvider>();

    // Версия ниже минимальной — дальше не пускаем. Проверка стоит здесь, а
    // не в конкретном экране, потому что несовместимой оказывается вся
    // работа с сервером, а не отдельная кнопка.
    //
    // Настройки грузятся асинхронно, и до их прихода `minVersion` пуст —
    // тогда `isBelow` вернёт false и человек спокойно работает. Пустое
    // значение в Directus означает то же самое: проверка выключена.
    final blocked = AppVersion.isBelow(AppVersion.version, settings.minVersion);

    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      title: 'Bagla',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru'), Locale('tk'), Locale('en')],
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      // G7: ограничиваем системный масштаб шрифта. Дизайн рассчитан на
      // фикс-размеры; при очень крупном системном шрифте (accessibility)
      // вёрстка с фикс-высотами кнопок/чипов ломалась бы. Clamp 0.85–1.2 —
      // уважаем настройку пользователя, но в безопасных пределах.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.2,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: blocked
          ? UpdateRequiredScreen(
              words: context.watch<LanguageProvider>().words,
              updateUrl: settings.updateUrl,
            )
          : home,
      onGenerateRoute: (settings) {
        if (settings.name == '/registration_details') {
          final role = settings.arguments as String? ?? 'client';
          return MaterialPageRoute(
            builder: (context) => RegistrationDetailsScreen(role: role),
          );
        }
        if (settings.name == '/login') {
          return MaterialPageRoute(builder: (_) => const PhoneScreen());
        }
        if (settings.name == '/user_type_selection') {
          return MaterialPageRoute(
            builder: (_) => const UserTypeSelectionScreen(),
          );
        }
        if (settings.name == '/home') {
          return MaterialPageRoute(builder: (_) => const MainShell());
        }
        if (settings.name == '/profile') {
          return MaterialPageRoute(
            builder: (_) => const MainShell(initialIndex: 2),
          );
        }
        if (settings.name == '/notifications') {
          return MaterialPageRoute(
            builder: (_) => const MainShell(initialIndex: 1),
          );
        }
        if (settings.name == '/appeals') {
          return MaterialPageRoute(builder: (_) => const AppealsScreen());
        }
        if (settings.name == '/transactions') {
          return MaterialPageRoute(
            builder: (_) => const TransactionHistoryScreen(),
          );
        }
        if (settings.name == '/reg-fix') {
          return MaterialPageRoute(
            builder: (_) => const RegistrationFixScreen(),
          );
        }
        if (settings.name == '/referrals') {
          return MaterialPageRoute(builder: (_) => const ReferralsScreen());
        }
        if (settings.name == '/trusted-couriers') {
          return MaterialPageRoute(
            builder: (_) => const TrustedCouriersScreen(),
          );
        }
        if (settings.name == '/traffic') {
          return MaterialPageRoute(builder: (_) => const TrafficScreen());
        }
        if (settings.name == '/terms') {
          return MaterialPageRoute(builder: (_) => const TermsScreen());
        }
        return null;
      },
    );
  }
}