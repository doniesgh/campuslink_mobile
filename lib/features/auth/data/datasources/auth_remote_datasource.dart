import 'package:dio/dio.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/interceptors/auth_interceptor.dart';
import '../models/auth_models.dart';

abstract interface class AuthRemoteDataSource {
  /// [identifier] is the student's ENT ID (e.g. 211JMT0428) or email.
  Future<AuthResponseModel> login(String identifier, String password);
  Future<AuthResponseModel> register(String name, String email, String password);
  /// Emails a 6-digit reset code (the API answers the same for unknown emails).
  Future<void> forgotPassword(String email);

  /// Sets a new password with the code emailed by [forgotPassword].
  Future<void> resetPassword(String email, String code, String password);
  Future<UserModel> verifyEmail(String code);
  Future<UserModel> me();

  /// Ends this device's session on the server (revokes [refreshToken]).
  Future<void> logout(String refreshToken);
}

/// Real implementation talking to the Node.js API.
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  const AuthRemoteDataSourceImpl(this._dio);
  final Dio _dio;

  Map<String, dynamic> _map(Response<dynamic> r) => r.data as Map<String, dynamic>;

  @override
  Future<AuthResponseModel> login(String identifier, String password) async {
    final r = await _dio.post(
      ApiEndpoints.login,
      data: {'identifier': identifier, 'password': password},
      options: AuthInterceptor.skipAuth,
    );
    return AuthResponseModel.fromJson(_map(r));
  }

  @override
  Future<AuthResponseModel> register(String name, String email, String password) async {
    final r = await _dio.post(
      ApiEndpoints.register,
      data: {'displayName': name, 'email': email, 'password': password},
      options: AuthInterceptor.skipAuth,
    );
    return AuthResponseModel.fromJson(_map(r));
  }

  @override
  Future<void> forgotPassword(String email) async {
    await _dio.post(
      ApiEndpoints.forgotPassword,
      data: {'email': email},
      options: AuthInterceptor.skipAuth,
    );
  }

  @override
  Future<void> resetPassword(String email, String code, String password) async {
    await _dio.post(
      ApiEndpoints.resetPassword,
      data: {'email': email, 'code': code, 'password': password},
      options: AuthInterceptor.skipAuth,
    );
  }

  @override
  Future<UserModel> verifyEmail(String code) async {
    final r = await _dio.post(ApiEndpoints.verifyEmail, data: {'code': code});
    return UserModel.fromJson(_map(r)['user'] as Map<String, dynamic>);
  }

  @override
  Future<UserModel> me() async => UserModel.fromJson(_map(await _dio.get(ApiEndpoints.me)));

  @override
  Future<void> logout(String refreshToken) async {
    await _dio.post(
      ApiEndpoints.logout,
      data: {'refreshToken': refreshToken},
      options: AuthInterceptor.skipAuth,
    );
  }
}

/// Fake implementation (USE_MOCK=true) so the app runs without a backend.
class MockAuthRemoteDataSource implements AuthRemoteDataSource {
  static const _delay = Duration(milliseconds: 600);

  UserModel _user(String email, {String name = 'Dony Mansour', bool verified = true}) =>
      UserModel(id: 'mock-1', email: email, displayName: name, isEmailVerified: verified);

  AuthResponseModel _session(UserModel u) =>
      AuthResponseModel(user: u, accessToken: 'mock-access', refreshToken: 'mock-refresh');

  @override
  Future<AuthResponseModel> login(String identifier, String password) async {
    await Future<void>.delayed(_delay);
    return _session(_user(identifier.contains('@') ? identifier : 'student@campus.test'));
  }

  @override
  Future<AuthResponseModel> register(String name, String email, String password) async {
    await Future<void>.delayed(_delay);
    return _session(_user(email, name: name, verified: false));
  }

  @override
  Future<void> forgotPassword(String email) => Future<void>.delayed(_delay);

  @override
  Future<void> resetPassword(String email, String code, String password) =>
      Future<void>.delayed(_delay);

  @override
  Future<UserModel> verifyEmail(String code) async {
    await Future<void>.delayed(_delay);
    return _user('student@campus.test');
  }

  @override
  Future<UserModel> me() async {
    await Future<void>.delayed(_delay);
    return _user('student@campus.test');
  }

  @override
  Future<void> logout(String refreshToken) async {}
}
