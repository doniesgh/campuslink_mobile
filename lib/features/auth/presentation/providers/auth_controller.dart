import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return Env.useMock
      ? MockAuthRemoteDataSource()
      : AuthRemoteDataSourceImpl(ref.watch(dioProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remote: ref.watch(authRemoteDataSourceProvider),
    storage: ref.watch(secureStorageProvider),
  );
});

/// Holds the current user: loading (restoring session), user, or null (signed out).
final authControllerProvider =
    AsyncNotifierProvider<AuthController, User?>(AuthController.new);

class AuthController extends AsyncNotifier<User?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<User?> build() async => (await _repo.restoreSession()).dataOrNull;

  /// Each action returns a [Failure] on error, or null on success.
  Future<Failure?> login(String email, String password) async {
    final r = await _repo.login(email: email, password: password);
    return r.when(
      success: (user) {
        state = AsyncData(user);
        return null;
      },
      failure: (f) => f,
    );
  }

  Future<Failure?> register(String name, String email, String password) async {
    final r = await _repo.register(displayName: name, email: email, password: password);
    return r.when(
      success: (user) {
        state = AsyncData(user);
        return null;
      },
      failure: (f) => f,
    );
  }

  Future<Failure?> forgotPassword(String email) async {
    final r = await _repo.forgotPassword(email);
    return r.when(success: (_) => null, failure: (f) => f);
  }

  Future<Failure?> verifyEmail(String code) async {
    final r = await _repo.verifyEmail(code);
    return r.when(
      success: (user) {
        state = AsyncData(user);
        return null;
      },
      failure: (f) => f,
    );
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncData(null);
  }

  /// Called by the Dio interceptor when the refresh token is no longer valid.
  void onSessionExpired() => state = const AsyncData(null);
}
