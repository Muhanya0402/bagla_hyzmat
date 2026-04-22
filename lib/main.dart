import 'package:bagla/features/auth/onboarding_screen.dart';
import 'package:bagla/features/notifications/notifications_screen.dart';
import 'package:bagla/features/profile/profile_screen.dart';
import 'package:bagla/providers/auth_provider.dart';
import 'package:bagla/providers/role_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/profile/registration_details_screen.dart';
import 'providers/language_provider.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/login_screen.dart';
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
      home = const LoginScreen();
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B3A6B),
          primary: const Color(0xFF1B3A6B),
        ),
        scaffoldBackgroundColor: Colors.white,
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
          return MaterialPageRoute(builder: (_) => const LoginScreen());
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
