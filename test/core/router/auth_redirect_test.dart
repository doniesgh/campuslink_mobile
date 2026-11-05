import 'package:campuspulse/core/router/app_router.dart';
import 'package:campuspulse/core/router/route_names.dart';
import 'package:campuspulse/features/auth/domain/entities/user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _verified = User(
  id: 'u1',
  email: 'student@campus.test',
  displayName: 'Student',
  isEmailVerified: true,
);
const _unverified = User(
  id: 'u1',
  email: 'student@campus.test',
  displayName: 'Student',
);

const AsyncValue<User?> _restoring = AsyncLoading<User?>();
const AsyncValue<User?> _signedOut = AsyncData<User?>(null);
const AsyncValue<User?> _signedIn = AsyncData<User?>(_verified);
const AsyncValue<User?> _pendingVerification = AsyncData<User?>(_unverified);

void main() {
  group('authRedirect', () {
    test('stays put while the session is being restored', () {
      expect(authRedirect(_restoring, RoutePaths.home), isNull);
    });

    group('signed out', () {
      test('is sent to login from app pages', () {
        expect(authRedirect(_signedOut, RoutePaths.home), RoutePaths.login);
        expect(authRedirect(_signedOut, RoutePaths.job('x')), RoutePaths.login);
      });

      test('is sent to login from verify-email (e.g. after signing out there)', () {
        expect(
          authRedirect(_signedOut, RoutePaths.verifyEmail),
          RoutePaths.login,
        );
      });

      test('can open the public auth pages', () {
        expect(authRedirect(_signedOut, RoutePaths.login), isNull);
        expect(authRedirect(_signedOut, RoutePaths.register), isNull);
        expect(authRedirect(_signedOut, RoutePaths.forgotPassword), isNull);
      });
    });

    group('email not verified', () {
      test('is sent to verify-email from anywhere else', () {
        expect(
          authRedirect(_pendingVerification, RoutePaths.home),
          RoutePaths.verifyEmail,
        );
        expect(
          authRedirect(_pendingVerification, RoutePaths.login),
          RoutePaths.verifyEmail,
        );
      });

      test('stays on verify-email', () {
        expect(authRedirect(_pendingVerification, RoutePaths.verifyEmail), isNull);
      });
    });

    group('signed in', () {
      test('is sent home from the auth pages', () {
        expect(authRedirect(_signedIn, RoutePaths.login), RoutePaths.home);
        expect(authRedirect(_signedIn, RoutePaths.register), RoutePaths.home);
        expect(authRedirect(_signedIn, RoutePaths.verifyEmail), RoutePaths.home);
      });

      test('can open app pages', () {
        expect(authRedirect(_signedIn, RoutePaths.jobs), isNull);
        expect(authRedirect(_signedIn, RoutePaths.ride('es-4091')), isNull);
      });
    });
  });
}
