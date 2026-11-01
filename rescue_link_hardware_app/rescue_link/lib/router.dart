import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rescue_link/screens/splash/splash_screen.dart';
import 'package:rescue_link/screens/home/home_screen.dart';
import 'package:rescue_link/screens/map/map_screen.dart';
import 'package:rescue_link/screens/network/network_screen.dart';
import 'package:rescue_link/screens/emergency/emergency_screen.dart';
import 'package:rescue_link/screens/devices/devices_screen.dart';
import 'package:rescue_link/screens/settings/settings_screen.dart';
import 'package:rescue_link/screens/shell/app_shell.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/map',
            builder: (context, state) => const MapScreen(),
          ),
          GoRoute(
            path: '/network',
            builder: (context, state) => const NetworkScreen(),
          ),
          GoRoute(
            path: '/emergency',
            builder: (context, state) => const EmergencyScreen(),
          ),
          GoRoute(
            path: '/devices',
            builder: (context, state) => const DevicesScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
