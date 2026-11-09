import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/providers/core_providers.dart';
import 'features/notifications/data/push/firebase_push_messaging.dart';
import 'features/notifications/presentation/push_controller.dart';

/// Initialises async dependencies, then starts the app.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // Null (push off) without a Firebase config: the app works the same.
  final push = await startPushMessaging();

  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        pushMessagingProvider.overrideWithValue(push),
      ],
      child: const CampusPulseApp(),
    ),
  );
}
