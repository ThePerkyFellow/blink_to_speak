import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
// Generated localizations - run `flutter gen-l10n` to generate
import 'providers/app_state_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/interpret_screen.dart';
import 'screens/practice_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/caregiver/caregiver_home.dart';
import 'screens/caregiver/command_list_screen.dart';
import 'screens/caregiver/command_edit_screen.dart';
import 'models/blink_command.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/',         builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/home',     builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/interpret',builder: (_, __) => const InterpretScreen()),
    GoRoute(path: '/practice', builder: (_, __) => const PracticeScreen()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    GoRoute(path: '/caregiver',builder: (_, __) => const CaregiverHome()),
    GoRoute(path: '/caregiver/commands', builder: (_, __) => const CommandListScreen()),
    GoRoute(
      path: '/caregiver/edit',
      builder: (ctx, state) {
        final cmd = state.extra as BlinkCommand?;
        return CommandEditScreen(command: cmd);
      },
    ),
  ],
);

class BlinkToSpeakApp extends StatelessWidget {
  const BlinkToSpeakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Blink to Speak',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: _buildTheme(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'IN'),
        Locale('hi', 'IN'),
        Locale('kn', 'IN'),
        Locale('ta', 'IN'),
        Locale('mr', 'IN'),
        Locale('te', 'IN'),
      ],
    );
  }

  ThemeData _buildTheme() {
    const primaryPink = Color(0xFFE8758A);
    const bgPink      = Color(0xFFFCECEF);
    const darkBlue    = Color(0xFF1A2B6D);
    const accentBlue  = Color(0xFF4A6CF7);

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Outfit',
      colorScheme: ColorScheme.light(
        primary:   primaryPink,
        secondary: accentBlue,
        surface:   bgPink,
        onPrimary: Colors.white,
        onSurface: darkBlue,
      ),
      scaffoldBackgroundColor: bgPink,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Outfit',
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: darkBlue,
        ),
        iconTheme: IconThemeData(color: darkBlue),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPink,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
