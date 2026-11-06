import 'dart:async';

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/auth_models.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({required this.remote, required this.storage});

  final AuthRemoteDataSource remote;
  final SecureStorage storage;

  Future<User> _persist(AuthResponseModel r) async {
    await storage.saveTokens(access: r.accessToken, refresh: r.refreshToken);
    return r.user.toEntity();
  }

  @override
  Future<Result<User>> login({required String identifier, required String password}) =>
      guard(() async => _persist(await remote.login(identifier, password)));

  @override
  Future<Result<User>> register({
    required String displayName,
    required String email,
    required String password,
  }) =>
      guard(() async => _persist(await remote.register(displayName, email, password)));

  @override
  Future<Result<void>> forgotPassword(String email) =>
      guard(() => remote.forgotPassword(email));

  @override
  Future<Result<User>> verifyEmail(String code) =>
      guard(() async => (await remote.verifyEmail(code)).toEntity());

  @override
  Future<Result<User?>> restoreSession() async {
    if (await storage.readAccessToken() == null) return const Success(null);
    final result = await guard(() async => (await remote.me()).toEntity());
    switch (result) {
      case Success(value: final user):
        return Success<User?>(user);
      case Err(failure: final f):
        if (f is UnauthorizedFailure) await storage.clear();
        return Err<User?>(f);
    }
  }

  /// Signs out locally right away, then revokes the session on the server in
  /// the background: the user never waits on (or is blocked by) the network.
  @override
  Future<void> logout() async {
    final refreshToken = await storage.readRefreshToken();
    await storage.clear();
    if (refreshToken != null) unawaited(guard(() => remote.logout(refreshToken)));
  }
}
