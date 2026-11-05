import 'package:dio/dio.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/interceptors/auth_interceptor.dart';
import '../models/auth_models.dart';

abstract interface class AuthRemoteDataSource {
  Future<AuthResponseModel> login(String email, String password);
  Future<AuthResponseModel> register(String name, String email, String password);
  Future<void> forgotPassword(String email);
  Future<UserModel> verifyEmail(String code);
  Future<UserModel> me();
}

/// Real implementation talking to the Node.js API.
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  const AuthRemoteDataSourceImpl(this._dio);
  final Dio _dio;

  Map<String, dynamic> _map(Response<dynamic> r) => r.data as Map<String, dynamic>;

  @override
  Future<AuthResponseModel> login(String email, String password) async {
    final r = await _dio.post(
      ApiEndpoints.login,
      data: {'email': email, 'password': password},
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
  Future<UserModel> verifyEmail(String code) async {
    final r = await _dio.post(ApiEndpoints.verifyEmail, data: {'code': code});
    return UserModel.fromJson(_map(r)['user'] as Map<String, dynamic>);
  }

  @override
  Future<UserModel> me() async => UserModel.fromJson(_map(await _dio.get(ApiEndpoints.me)));
}

/// Fake implementation (USE_MOCK=true) so the app runs without a backend.
class MockAuthRemoteDataSource implements AuthRemoteDataSource {
  static const _delay = Duration(milliseconds: 600);

  UserModel _user(String email, {String name = 'Campus Student', bool verified = true}) =>
      UserModel(id: 'mock-1', email: email, displayName: name, isEmailVerified: verified);

  AuthResponseModel _session(UserModel u) =>
      AuthResponseModel(user: u, accessToken: 'mock-access', refreshToken: 'mock-refresh');

  @override
  Future<AuthResponseModel> login(String email, String password) async {
    await Future<void>.delayed(_delay);
    return _session(_user(email));
  }

  @override
  Future<AuthResponseModel> register(String name, String email, String password) async {
    await Future<void>.delayed(_delay);
    return _session(_user(email, name: name, verified: false));
  }

  @override
  Future<void> forgotPassword(String email) => Future<void>.delayed(_delay);

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
}
