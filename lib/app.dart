import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/core_providers.dart';
import 'core/providers/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/notifications/presentation/push_controller.dart';

/// Root widget: wires theme, theme mode, router and push notifications.
class CampusPulseApp extends ConsumerWidget {
  const CampusPulseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps push notifications running while the app does (null when off).
    ref.watch(pushControllerProvider);
    return MaterialApp.router(
      title: 'CampusPulse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
      scaffoldMessengerKey: ref.watch(scaffoldMessengerKeyProvider),
    );
  }
}
