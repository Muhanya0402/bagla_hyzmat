import 'package:bagla/features/auth/onboarding_screen.dart';
import 'package:bagla/features/notifications/notifications_screen.dart';
import 'package:bagla/features/profile/profile_screen.dart';
import 'package:bagla/providers/auth_provider.dart';
import 'package:bagla/providers/level_provider.dart';
import 'package:bagla/providers/role_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/profile/registration_details_screen.dart';
import 'providers/language_provider.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/phone_screen.dart';
import 'features/home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final langProvider = LanguageProvider();
  await langProvider.loadSavedLanguage();

  final prefs = await SharedPreferences.getInstance();
  final bool loggedIn = await AuthRepository.checkAuthStatus();
  final bool onboardingDone = prefs.getBool('onboarding_done') ?? false;
  final String status = prefs.getString('status') ?? 'pending';

  final bool showOnboarding =
      loggedIn && !onboardingDone && status == 'pending';

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RoleProvider()),
        ChangeNotifierProvider(create: (_) => LevelProvider()), // 👈 ВОТ ЭТО
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
    Widget home;
    if (!isLoggedIn) {
      home = const PhoneScreen();
    } else if (showOnboarding) {
      home = const OnboardingScreen();
    } else {
      home = const HomeScreen();
    }

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Bagla',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Nunito', // — глобальный шрифт
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B3A6B),
          primary: const Color(0xFF1B3A6B),
        ),
        scaffoldBackgroundColor: Colors.white,
        // Глобальные стили текста
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
        // Глобальный стиль AppBar
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
        // Глобальный стиль ElevatedButton
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            textStyle: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // Глобальный стиль TextField
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
        if (settings.name == '/home') {
          return MaterialPageRoute(builder: (_) => const HomeScreen());
        }
        if (settings.name == '/profile') {
          return MaterialPageRoute(builder: (_) => const ProfileScreen());
        }
        if (settings.name == '/onboarding') {
          return MaterialPageRoute(builder: (_) => const OnboardingScreen());
        }
        if (settings.name == '/notifications') {
          return MaterialPageRoute(builder: (_) => const NotificationsScreen());
        }
        return null;
      },
    );
  }
}
