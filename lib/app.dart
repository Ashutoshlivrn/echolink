import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/splash/splash_screen.dart';
import 'services/session_controller.dart';

class AudioSharingApp extends StatelessWidget {
  const AudioSharingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SessionController>(
      create: (_) => SessionController(),
      child: MaterialApp(
        title: 'SyncAudio',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6366F1), // Modern Indigo
            brightness: Brightness.light,
          ),
          fontFamily: 'Roboto',
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: ZoomPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            },
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6366F1),
            brightness: Brightness.dark,
          ),
          fontFamily: 'Roboto',
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: ZoomPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            },
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
