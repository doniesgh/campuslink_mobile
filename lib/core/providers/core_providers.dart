import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/presentation/providers/auth_controller.dart';
import '../network/dio_client.dart';
import '../storage/local_prefs.dart';
import '../storage/secure_storage.dart';

/// Overridden in bootstrap.dart once SharedPreferences is loaded.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('sharedPrefsProvider must be overridden'),
);

final localPrefsProvider =
    Provider<LocalPrefs>((ref) => LocalPrefs(ref.watch(sharedPrefsProvider)));

final secureStorageProvider = Provider<SecureStorage>(
  (_) => const SecureStorage(FlutterSecureStorage()),
);

final dioProvider = Provider<Dio>((ref) {
  return DioClient.create(
    storage: ref.watch(secureStorageProvider),
    onSessionExpired: () =>
        ref.read(authControllerProvider.notifier).onSessionExpired(),
  );
});
