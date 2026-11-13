import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:campuspulse/core/router/app_router.dart';
import 'package:campuspulse/core/router/route_names.dart';
import 'package:campuspulse/core/storage/secure_storage.dart';
import 'package:campuspulse/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:campuspulse/features/auth/data/models/auth_models.dart';
import 'package:campuspulse/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:campuspulse/features/auth/domain/entities/user.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Real answers of the API (backend/test/account.test.ts).
final Map<String, dynamic> _api = jsonDecode(
  File('test/features/admin/fixtures/admin_api.json').readAsStringSync(),
) as Map<String, dynamic>;

/// Answers every request with [reply] and records what was sent.
class _FakeApi implements HttpClientAdapter {
  _FakeApi(this.reply);

  final (int, Object) Function(RequestOptions request) reply;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = reply(options);
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

(AuthRepositoryImpl, _FakeApi) _repo((int, Object) Function(RequestOptions) reply) {
  final api = _FakeApi(reply);
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api'))..httpClientAdapter = api;
  return (
    AuthRepositoryImpl(
      remote: AuthRemoteDataSourceImpl(dio),
      storage: const SecureStorage(FlutterSecureStorage()),
    ),
    api,
  );
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('updateMe sends PATCH /users/me with only the language, and reads the account', () async {
    final (repo, api) = _repo((_) => (200, _api['meWithLocale'] as Object));

    final user = (await repo.updateMe(locale: 'en')).unwrap();

    expect(api.requests.single.method, 'PATCH');
    expect(api.requests.single.path, '/users/me');
    expect(api.requests.single.data, {'locale': 'en'});
    expect(user.locale, 'en');
    expect(user.displayName, 'Sarra Kefi');
  });

  test('register sends the language of the new account', () async {
    final session = {
      'user': _api['meWithLocale'],
      'accessToken': 'access',
      'refreshToken': 'refresh',
    };
    final (repo, api) = _repo((_) => (201, session));

    final user = (await repo.register(
      displayName: 'Sarra Kefi',
      email: 'sarra.kefi@campus.test',
      password: 'password123',
      locale: 'en',
    ))
        .unwrap();

    expect(api.requests.single.data, {
      'displayName': 'Sarra Kefi',
      'email': 'sarra.kefi@campus.test',
      'password': 'password123',
      'locale': 'en',
    });
    expect(user.locale, 'en');
  });

  test('a user without (or with an unknown) locale reads as French', () {
    Map<String, dynamic> user(Object? locale) => {
          'id': 'u1',
          'email': 'a@campus.test',
          'displayName': 'A',
          'role': 'company',
          if (locale != null) 'locale': locale,
        };
    expect(UserModel.fromJson(user(null)).locale, 'fr');
    expect(UserModel.fromJson(user('de')).locale, 'fr');
    expect(UserModel.fromJson(user('EN')).locale, 'en');
    expect(UserModel.fromJson(user('en')).toEntity().role, UserRole.company);
    expect(UserModel.fromJson(user('en')).toEntity().hasClasses, isFalse);
  });

  test('the demo sign-up gives a verified account that goes straight to Home', () async {
    final session = await MockAuthRemoteDataSource()
        .register('Sarra Kefi', 'sarra.kefi@campus.test', 'password123');
    final user = session.user.toEntity();

    expect(user.isEmailVerified, isTrue);
    expect(authRedirect(AsyncData<User?>(user), RoutePaths.register), RoutePaths.home);
    expect(authRedirect(AsyncData<User?>(user), RoutePaths.home), isNull);
  });

  test('the demo mode keeps the language like the API', () async {
    final mock = MockAuthRemoteDataSource();
    expect((await mock.me()).locale, 'fr');
    expect((await mock.updateMe(locale: 'en')).locale, 'en');
    expect((await mock.login('student@campus.test', 'pw')).user.locale, 'en');
  });
}
