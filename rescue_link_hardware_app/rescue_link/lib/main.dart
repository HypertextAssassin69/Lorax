import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rescue_link/core/theme/app_theme.dart';
import 'package:rescue_link/providers/settings_provider.dart';
import 'package:rescue_link/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: RescueLinkApp()));
}

class RescueLinkApp extends ConsumerWidget {
  const RescueLinkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: 'RescueLink',
      routerConfig: router,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
    );
  }
}
