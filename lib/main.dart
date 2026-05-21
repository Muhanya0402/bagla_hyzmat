import 'package:bagla/features/auth/onboarding_screen.dart';
import 'package:bagla/features/shell/main_shell.dart';
import 'package:bagla/features/profile/appeals_screen.dart';
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
  final bool loggedIn = await AuthRepository.checkAuthStatus();
  final bool onboardingDone = prefs.getBool('onboarding_done') ?? false;
  final String status = prefs.getString('status') ?? 'pending';
  final bool showOnboarding =
      loggedIn && !onboardingDone && status == 'pending';

  if (loggedIn) {
    await PushNotificationService().initialize();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RoleProvider()),
        ChangeNotifierProvider(create: (_) => LevelProvider()),
        ChangeNotifierProvider.value(value: langProvider),
      ],
      child: MyApp(isLoggedIn: loggedIn, showOnboarding: showOnboarding),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final bool showOnboarding;

  const MyApp({
    super.key,
    required this.isLoggedIn,
    required this.showOnboarding,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ Главная обёртка теперь MainShell (содержит Home + Notifications + Profile)
    Widget home;
    if (!isLoggedIn) {
      home = const PhoneScreen();
    } else if (showOnboarding) {
      home = const OnboardingScreen();
    } else {
      home = const MainShell(); // ← было HomeScreen()
    }

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

      // ─────────────────────────────────────────────────────────────────────
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Nunito',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B3A6B),
          primary: const Color(0xFF1B3A6B),
        ),
        scaffoldBackgroundColor: Colors.white,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontFamily: 'Nunito'),
          bodyMedium: TextStyle(fontFamily: 'Nunito'),
          bodySmall: TextStyle(fontFamily: 'Nunito'),
          titleLarge: TextStyle(fontFamily: 'Nunito'),
          titleMedium: TextStyle(fontFamily: 'Nunito'),
          titleSmall: TextStyle(fontFamily: 'Nunito'),
          labelLarge: TextStyle(fontFamily: 'Nunito'),
          labelMedium: TextStyle(fontFamily: 'Nunito'),
          labelSmall: TextStyle(fontFamily: 'Nunito'),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F1117),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            textStyle: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          hintStyle: TextStyle(
            fontFamily: 'Nunito',
            color: Colors.grey.shade400,
          ),
        ),
      ),
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
        if (settings.name == '/onboarding') {
          return MaterialPageRoute(builder: (_) => const OnboardingScreen());
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
