import 'package:dio/dio.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/interceptors/auth_interceptor.dart';
import '../../domain/entities/user.dart';
import '../models/auth_models.dart';

abstract interface class AuthRemoteDataSource {
  /// [identifier] is the student's ENT ID (e.g. 211JMT0428) or email.
  Future<AuthResponseModel> login(String identifier, String password);
  /// [locale] ("fr" or "en"): the account's language (emails, notifications).
  Future<AuthResponseModel> register(
    String name,
    String email,
    String password, {
    String? locale,
  });
  /// Emails a 6-digit reset code (the API answers the same for unknown emails).
  Future<void> forgotPassword(String email);

  /// Sets a new password with the code emailed by [forgotPassword].
  Future<void> resetPassword(String email, String code, String password);
  Future<UserModel> me();

  /// `PATCH /users/me`: changes the given settings of the signed-in account
  /// (only [locale] for now) and returns the account.
  Future<UserModel> updateMe({String? locale});

  /// Ends this device's session on the server (revokes [refreshToken]) and
  /// stops its push notifications ([pushToken]).
  Future<void> logout(String refreshToken, {String? pushToken});
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
  Future<AuthResponseModel> register(
    String name,
    String email,
    String password, {
    String? locale,
  }) async {
    final r = await _dio.post(
      ApiEndpoints.register,
      data: {
        'displayName': name,
        'email': email,
        'password': password,
        if (locale != null) 'locale': locale,
      },
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
  Future<UserModel> me() async => UserModel.fromJson(_map(await _dio.get(ApiEndpoints.me)));

  @override
  Future<UserModel> updateMe({String? locale}) async {
    final r = await _dio.patch(ApiEndpoints.me, data: {
      if (locale != null) 'locale': locale,
    });
    return UserModel.fromJson(_map(r));
  }

  @override
  Future<void> logout(String refreshToken, {String? pushToken}) async {
    await _dio.post(
      ApiEndpoints.logout,
      data: {
        'refreshToken': refreshToken,
        if (pushToken != null) 'pushToken': pushToken,
      },
      options: AuthInterceptor.skipAuth,
    );
  }
}

/// Fake implementation (USE_MOCK=true) so the app runs without a backend.
class MockAuthRemoteDataSource implements AuthRemoteDataSource {
  /// Id of the demo admin. The mock admin repository knows it too, so the
  /// "(you)" label and the own-account rules work offline.
  static const adminId = 'mock-admin';

  static const _delay = Duration(milliseconds: 600);

  /// The demo account's language, as the API would keep it.
  String _locale = 'fr';

  /// An identifier containing "admin" (e.g. admin@campus.test) signs in as
  /// the demo admin, so the Administration screens can be tried offline.
  UserModel _user(String email, {String name = 'Dony Mansour'}) {
    final admin = email.toLowerCase().contains('admin');
    return UserModel(
      id: admin ? adminId : 'mock-1',
      email: email,
      displayName: admin ? 'Campus Admin' : name,
      isEmailVerified: true,
      role: admin ? UserRole.admin : UserRole.student,
      locale: _locale,
    );
  }

  AuthResponseModel _session(UserModel u) =>
      AuthResponseModel(user: u, accessToken: 'mock-access', refreshToken: 'mock-refresh');

  @override
  Future<AuthResponseModel> login(String identifier, String password) async {
    await Future<void>.delayed(_delay);
    return _session(_user(identifier.contains('@') ? identifier : 'student@campus.test'));
  }

  @override
  Future<AuthResponseModel> register(
    String name,
    String email,
    String password, {
    String? locale,
  }) async {
    await Future<void>.delayed(_delay);
    if (locale != null) _locale = locale;
    // Like the API: the new account is verified and signed in at once.
    return _session(_user(email, name: name));
  }

  @override
  Future<void> forgotPassword(String email) => Future<void>.delayed(_delay);

  @override
  Future<void> resetPassword(String email, String code, String password) =>
      Future<void>.delayed(_delay);

  @override
  Future<UserModel> me() async {
    await Future<void>.delayed(_delay);
    return _user('student@campus.test');
  }

  @override
  Future<UserModel> updateMe({String? locale}) async {
    await Future<void>.delayed(_delay);
    if (locale != null) _locale = locale;
    return _user('student@campus.test');
  }

  @override
  Future<void> logout(String refreshToken, {String? pushToken}) async {}
}
