import 'package:campuspulse/core/error/failures.dart';
import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/core/l10n/app_language.dart';
import 'package:campuspulse/core/providers/core_providers.dart';
import 'package:campuspulse/core/providers/locale_provider.dart';
import 'package:campuspulse/features/auth/domain/entities/user.dart';
import 'package:campuspulse/features/auth/domain/repositories/auth_repository.dart';
import 'package:campuspulse/features/auth/presentation/providers/auth_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sarra = User(
  id: 'u-sarra',
  email: 'sarra@campus.test',
  displayName: 'Sarra Mansouri',
  isEmailVerified: true,
);

/// The real AuthController runs on this: what it sends to `PATCH /users/me`.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.signedIn});

  User? signedIn;
  final patches = <String?>[];
  final registeredLocales = <String?>[];
  Failure? failure;
  bool throws = false;

  @override
  Future<Result<User?>> restoreSession() async => Success(signedIn);

  @override
  Future<Result<User>> login({required String identifier, required String password}) async =>
      Success(signedIn!);

  @override
  Future<Result<User>> register({
    required String displayName,
    required String email,
    required String password,
    String? locale,
  }) async {
    registeredLocales.add(locale);
    return Success(signedIn = _sarra.copyWith(locale: locale));
  }

  @override
  Future<Result<User>> updateMe({String? locale}) async {
    patches.add(locale);
    if (throws) throw StateError('offline');
    final failure = this.failure;
    if (failure != null) return Err(failure);
    return Success(signedIn = signedIn!.copyWith(locale: locale));
  }

  @override
  Future<void> logout({String? pushToken}) async => signedIn = null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<ProviderContainer> _container({
  Map<String, Object> prefs = const {},
  List<Locale> device = const [Locale('en', 'US')],
  _FakeAuthRepository? auth,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final shared = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPrefsProvider.overrideWithValue(shared),
    deviceLocalesProvider.overrideWithValue(device),
    authRepositoryProvider.overrideWithValue(auth ?? _FakeAuthRepository()),
  ]);
  addTearDown(container.dispose);
  await container.read(authControllerProvider.future);
  return container;
}

User? _user(ProviderContainer c) => c.read(authControllerProvider).valueOrNull;

void main() {
  group('the language on screen', () {
    test("follows the device when it is French or English", () async {
      expect((await _container(device: const [Locale('en', 'US')])).read(localeProvider),
          AppLanguage.en);
      expect((await _container(device: const [Locale('ar', 'TN'), Locale('fr')])).read(localeProvider),
          AppLanguage.fr);
    });

    test('is French for any other device language', () async {
      final c = await _container(device: const [Locale('de', 'DE')]);
      expect(c.read(localeProvider), AppLanguage.fr);
    });

    test("is the user's choice once made, and the choice is saved", () async {
      final c = await _container(prefs: {'locale': 'fr'}, device: const [Locale('en')]);
      expect(c.read(localeProvider), AppLanguage.fr);

      c.read(localeProvider.notifier).set(AppLanguage.en);
      expect(c.read(localeProvider), AppLanguage.en);
      await pumpEventQueue();
      expect((await SharedPreferences.getInstance()).getString('locale'), 'en');
    });
  });

  group("the account's language", () {
    test('follows a change made while signed in', () async {
      final auth = _FakeAuthRepository(signedIn: _sarra);
      final c = await _container(auth: auth, device: const [Locale('fr')]);

      c.read(localeProvider.notifier).set(AppLanguage.en);
      await pumpEventQueue();

      expect(auth.patches, ['en']);
      expect(_user(c)?.locale, 'en');
    });

    test('is left alone when it already matches, or when signed out', () async {
      final signedIn = _FakeAuthRepository(signedIn: _sarra);
      final c = await _container(auth: signedIn, device: const [Locale('en')]);
      c.read(localeProvider.notifier).set(AppLanguage.fr); // the account is already in French
      await pumpEventQueue();
      expect(signedIn.patches, isEmpty);

      final signedOut = _FakeAuthRepository();
      final c2 = await _container(auth: signedOut);
      c2.read(localeProvider.notifier).set(AppLanguage.fr);
      await pumpEventQueue();
      expect(signedOut.patches, isEmpty);
    });

    test('after sign-in, takes the language on screen when it differs', () async {
      final auth = _FakeAuthRepository();
      final c = await _container(auth: auth, device: const [Locale('en', 'GB')]);

      auth.signedIn = _sarra; // the account says French
      await c.read(authControllerProvider.notifier).login('sarra@campus.test', 'pw');
      await pumpEventQueue();

      expect(auth.patches, ['en']);
      expect(_user(c)?.locale, 'en');
      // The screen keeps its language.
      expect(c.read(localeProvider), AppLanguage.en);
    });

    test('after sign-in, nothing is sent when they already match', () async {
      final auth = _FakeAuthRepository();
      final c = await _container(auth: auth, device: const [Locale('fr', 'TN')]);
      auth.signedIn = _sarra;
      await c.read(authControllerProvider.notifier).login('sarra@campus.test', 'pw');
      await pumpEventQueue();
      expect(auth.patches, isEmpty);
    });

    test('a new account is created in the language on screen', () async {
      final auth = _FakeAuthRepository();
      final c = await _container(auth: auth, prefs: {'locale': 'en'});

      await c.read(authControllerProvider.notifier).register('Sarra', 'sarra@campus.test', 'pw123456');
      await pumpEventQueue();

      expect(auth.registeredLocales, ['en']);
      expect(auth.patches, isEmpty);
      expect(_user(c)?.locale, 'en');
    });

    test('a failure is ignored: the screen keeps the language', () async {
      final auth = _FakeAuthRepository(signedIn: _sarra)..failure = const NetworkFailure();
      final c = await _container(auth: auth, device: const [Locale('fr')]);

      c.read(localeProvider.notifier).set(AppLanguage.en);
      await pumpEventQueue();
      expect(auth.patches, ['en']);
      expect(_user(c)?.locale, 'fr');
      expect(c.read(localeProvider), AppLanguage.en);

      auth
        ..failure = null
        ..throws = true;
      c.read(localeProvider.notifier).set(AppLanguage.en);
      await pumpEventQueue();
      expect(auth.patches, ['en', 'en']);
      expect(c.read(localeProvider), AppLanguage.en);
    });
  });
}
