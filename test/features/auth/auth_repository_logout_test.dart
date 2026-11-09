import 'package:campuspulse/core/storage/secure_storage.dart';
import 'package:campuspulse/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:campuspulse/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records logout calls; every other member is unused here.
class _FakeRemote implements AuthRemoteDataSource {
  final logouts = <String>[];
  final pushTokens = <String?>[];
  bool offline = false;

  @override
  Future<void> logout(String refreshToken, {String? pushToken}) async {
    logouts.add(refreshToken);
    pushTokens.add(pushToken);
    if (offline) throw Exception('no network');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeRemote remote;
  late SecureStorage storage;
  late AuthRepositoryImpl repo;

  void signedInAs(String access, String refresh) {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': access,
      'refresh_token': refresh,
    });
  }

  setUp(() {
    remote = _FakeRemote();
    storage = const SecureStorage(FlutterSecureStorage());
    repo = AuthRepositoryImpl(remote: remote, storage: storage);
  });

  test('clears the tokens and revokes the session on the server', () async {
    signedInAs('access-1', 'refresh-1');
    await repo.logout();
    await pumpEventQueue();

    expect(await storage.readAccessToken(), isNull);
    expect(await storage.readRefreshToken(), isNull);
    expect(remote.logouts, ['refresh-1']);
    expect(remote.pushTokens, [null]);
  });

  test("sends the phone's push token, so the server stops pushing to it", () async {
    signedInAs('access-1', 'refresh-1');
    await repo.logout(pushToken: 'fcm-token-1');
    await pumpEventQueue();

    expect(remote.pushTokens, ['fcm-token-1']);
  });

  test('offline: still signs out locally and does not throw', () async {
    signedInAs('access-1', 'refresh-1');
    remote.offline = true;

    await repo.logout();
    await pumpEventQueue();

    expect(await storage.readRefreshToken(), isNull);
    expect(remote.logouts, ['refresh-1']);
  });

  test('already signed out: no server call', () async {
    FlutterSecureStorage.setMockInitialValues({});
    await repo.logout();
    await pumpEventQueue();

    expect(remote.logouts, isEmpty);
  });
}
