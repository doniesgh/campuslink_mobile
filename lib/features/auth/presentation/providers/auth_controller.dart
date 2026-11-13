import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/l10n/app_language.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/locale_provider.dart';
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

/// Id of the signed-in student, or null. Caches that hold one student's data
/// and outlive a screen watch it, so they reload when another student signs
/// in on the same phone (instead of showing the previous student's data).
final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(authControllerProvider.select((auth) => auth.valueOrNull?.id)),
);

class AuthController extends AsyncNotifier<User?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<User?> build() async => (await _repo.restoreSession()).dataOrNull;

  /// Each action returns a [Failure] on error, or null on success.
  ///
  /// After signing in, the app keeps the language on screen: if the
  /// account's differs, the account is updated (see [syncLanguage]).
  Future<Failure?> login(String identifier, String password) async {
    final r = await _repo.login(identifier: identifier, password: password);
    return r.when(
      success: (user) {
        state = AsyncData(user);
        unawaited(syncLanguage(ref.read(localeProvider)));
        return null;
      },
      failure: (f) => f,
    );
  }

  /// The new account gets the language on screen. It is signed in at once
  /// (no email verification): the router opens Home.
  Future<Failure?> register(String name, String email, String password) async {
    final r = await _repo.register(
      displayName: name,
      email: email,
      password: password,
      locale: ref.read(localeProvider).code,
    );
    return r.when(
      success: (user) {
        state = AsyncData(user);
        unawaited(syncLanguage(ref.read(localeProvider)));
        return null;
      },
      failure: (f) => f,
    );
  }

  /// Makes the signed-in account's language [language] (`PATCH /users/me`),
  /// so the server writes this user's emails and notifications in the
  /// language they read the app in. Does nothing when signed out or already
  /// equal; a failure is ignored (best effort: the next sign-in tries again).
  Future<void> syncLanguage(AppLanguage language) async {
    final user = state.valueOrNull;
    if (user == null || user.locale == language.code) return;
    try {
      final result = await _repo.updateMe(locale: language.code);
      if (result case Success(value: final updated)) {
        // Only if the same user is still signed in (they may have signed out meanwhile).
        if (state.valueOrNull?.id == updated.id) state = AsyncData(updated);
      }
    } catch (_) {
      // Best effort: the language on screen is what matters.
    }
  }

  Future<Failure?> forgotPassword(String email) async {
    final r = await _repo.forgotPassword(email);
    return r.when(success: (_) => null, failure: (f) => f);
  }

  /// Sets a new password with the emailed code. The student then signs in
  /// again (the server ends every existing session).
  Future<Failure?> resetPassword(String email, String code, String password) async {
    final r = await _repo.resetPassword(email: email, code: code, password: password);
    return r.when(success: (_) => null, failure: (f) => f);
  }

  Future<void> logout() async {
    await _repo.logout(pushToken: ref.read(pushTokenProvider));
    state = const AsyncData(null);
  }

  /// Called by the Dio interceptor when the refresh token is no longer valid.
  void onSessionExpired() => state = const AsyncData(null);

  /// Shows at once the name and email an admin just saved on their own
  /// account (from the Users screens), without asking the server again.
  void updateOwnAccount({required String displayName, required String email}) {
    final user = state.valueOrNull;
    if (user == null) return;
    state = AsyncData(user.copyWith(email: email, displayName: displayName));
  }
}
