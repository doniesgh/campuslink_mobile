import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/presentation/providers/auth_controller.dart';
import '../network/dio_client.dart';
import '../storage/local_prefs.dart';
import '../storage/secure_storage.dart';
import 'locale_provider.dart';

/// Overridden in bootstrap.dart once SharedPreferences is loaded.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('sharedPrefsProvider must be overridden'),
);

final localPrefsProvider =
    Provider<LocalPrefs>((ref) => LocalPrefs(ref.watch(sharedPrefsProvider)));

final secureStorageProvider = Provider<SecureStorage>(
  (_) => const SecureStorage(FlutterSecureStorage()),
);

/// The app's root ScaffoldMessenger, for snackbars shown from outside the
/// widget tree (e.g. a push notification that arrives while the app is open).
final scaffoldMessengerKeyProvider =
    Provider<GlobalKey<ScaffoldMessengerState>>((_) => GlobalKey<ScaffoldMessengerState>());

/// The push token this phone registered for the signed-in user, or null (push
/// off, permission refused, signed out). Sent with logout so the server stops
/// pushing to this phone.
final pushTokenProvider = StateProvider<String?>((_) => null);

final dioProvider = Provider<Dio>((ref) {
  return DioClient.create(
    storage: ref.watch(secureStorageProvider),
    onSessionExpired: () =>
        ref.read(authControllerProvider.notifier).onSessionExpired(),
    languageCode: () => ref.read(localeProvider).code,
  );
});
