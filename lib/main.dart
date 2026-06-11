import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'providers/device_provider.dart';
import 'providers/server_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/devices_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/server/server_dashboard_screen.dart';
import 'screens/server/server_login_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const PhotoFrameApp());
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/devices',
      builder: (context, state) => const DevicesScreen(),
    ),
    GoRoute(
      path: '/gallery',
      builder: (context, state) => const GalleryScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/server/login',
      builder: (context, state) => const ServerLoginScreen(),
    ),
    GoRoute(
      path: '/server',
      builder: (context, state) => const ServerDashboardScreen(),
    ),
  ],
);

class PhotoFrameApp extends StatelessWidget {
  const PhotoFrameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
        ChangeNotifierProvider(create: (_) => ServerProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp.router(
          title: 'ESP32 PhotoFrame',
          theme: themeProvider.light,
          darkTheme: themeProvider.dark,
          themeMode: themeProvider.mode,
          routerConfig: _router,
        ),
      ),
    );
  }
}
