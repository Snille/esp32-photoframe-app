import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/server_provider.dart';
import '../services/server_api_client.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    // Decide the landing screen: server mode if a connection was saved,
    // otherwise the existing local device mode.
    final saved = await ServerApiClient.loadSaved();
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    if (saved != null) {
      // Restore in the background; the dashboard also reloads on entry.
      context.read<ServerProvider>().restore();
      context.go('/server');
    } else {
      context.go('/devices');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF3D2817),
              Color(0xFF7A4E2B),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/splash_icon.png',
                width: 210,
                height: 210,
              ),
              const SizedBox(height: 24),
              Text(
                'ESP Frame',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: const Color(0xFFF0E4D0),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Companion app for the ESP32 PhotoFrame Project',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFF0E4D0).withValues(alpha: 0.6),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
