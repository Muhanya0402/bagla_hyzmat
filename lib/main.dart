import 'package:bagla/core/app_settings_provider.dart';
import 'package:bagla/core/theme/app_theme.dart';
import 'package:bagla/core/theme/theme_provider.dart';
import 'package:bagla/core/tour/tour_manager.dart';
import 'package:bagla/features/appeals/appeals_screen.dart';
import 'package:bagla/features/shell/main_shell.dart';
import 'package:bagla/features/profile/terms_screen.dart';
import 'package:bagla/features/profile/user_type_selection_screen.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/features/levels/level_provider.dart';
import 'package:bagla/providers/role_provider.dart';
import 'package:bagla/features/notifications/push_notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/profile/registration_details_screen.dart';
import 'l10n/language_provider.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/phone_screen.dart';

// ✅ Новый импорт — главная обёртка с BottomNavigationBar

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (e) {
    if (kDebugMode) print('❌ Ошибка Firebase.initializeApp: $e');
  }
  if (kDebugMode) print('Фоновое сообщение: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru', null);

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  final langProvider = LanguageProvider();
  await langProvider.loadSavedLanguage();

  final prefs = await SharedPreferences.getInstance();
  final themeProvider = ThemeProvider.fromPrefs(prefs);
  await TourManager.instance.init();

  final bool loggedIn = await AuthRepository.checkAuthStatus();
  // Роль считается выбранной, если она сохранена и не пустая.
  final String savedRole = prefs.getString('role') ?? '';
  final bool needsRoleSelection = loggedIn && savedRole.isEmpty;

  if (loggedIn) {
    await PushNotificationService().initialize();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RoleProvider()),
        ChangeNotifierProvider(create: (_) => LevelProvider()),
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
        ChangeNotifierProvider.value(value: langProvider),
        ChangeNotifierProvider.value(value: themeProvider),
      ],
      child: MyApp(isLoggedIn: loggedIn, needsRoleSelection: needsRoleSelection),
    ),
  );
}

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
      // Первый вход: пользователь выбирает роль, затем попадает в MainShell.
      home = const UserTypeSelectionScreen();
    } else {
      home = const MainShell();
    }

    final themeMode = context.watch<ThemeProvider>().themeMode;

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Bagla',

      // ── Локализации ──────────────────────────────────────────────────────
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru'), Locale('tk'), Locale('en')],

      theme:     AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: home,
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
        if (settings.name == '/terms') {
          return MaterialPageRoute(builder: (_) => const TermsScreen());
        }
        return null;
      },
    );
  }
}
