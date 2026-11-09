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
        expect(authRedirect(_signedOut, RoutePaths.resetPassword), isNull);
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

    group('administration', () {
      const admin = AsyncData<User?>(User(
        id: 'a1',
        email: 'admin@campus.test',
        displayName: 'Campus Admin',
        isEmailVerified: true,
        role: UserRole.admin,
      ));
      const teacher = AsyncData<User?>(User(
        id: 't1',
        email: 'teacher@campus.test',
        displayName: 'Teacher',
        isEmailVerified: true,
        role: UserRole.teacher,
      ));
      final adminPages = [
        RoutePaths.adminUsers,
        RoutePaths.newUser,
        RoutePaths.adminUser('u1'),
        RoutePaths.importUsers,
        RoutePaths.auditLog,
      ];

      test('is open to admins', () {
        for (final page in adminPages) {
          expect(authRedirect(admin, page), isNull, reason: page);
        }
      });

      test('sends students and teachers back to Profile', () {
        for (final page in adminPages) {
          expect(authRedirect(_signedIn, page), RoutePaths.profile, reason: page);
          expect(authRedirect(teacher, page), RoutePaths.profile, reason: page);
        }
      });

      test('leaves the rest of the Profile tab alone', () {
        expect(authRedirect(_signedIn, RoutePaths.profile), isNull);
        expect(authRedirect(_signedIn, RoutePaths.grades), isNull);
      });

      test('signed-out users still go to login first', () {
        expect(authRedirect(_signedOut, RoutePaths.adminUsers), RoutePaths.login);
      });
    });

    group('timetable', () {
      AsyncValue<User?> signedInAs(UserRole role) => AsyncData<User?>(User(
            id: 'u1',
            email: 'someone@campus.test',
            displayName: 'Someone',
            isEmailVerified: true,
            role: role,
          ));
      final timetablePages = [RoutePaths.timetable, RoutePaths.courses];

      test('is open to students and teachers', () {
        for (final role in [UserRole.student, UserRole.teacher]) {
          for (final page in timetablePages) {
            expect(authRedirect(signedInAs(role), page), isNull, reason: '$role $page');
          }
        }
      });

      test('sends admins and alumni home: they have no timetable', () {
        for (final role in [UserRole.admin, UserRole.alumni]) {
          for (final page in timetablePages) {
            expect(authRedirect(signedInAs(role), page), RoutePaths.home, reason: '$role $page');
          }
          expect(authRedirect(signedInAs(role), RoutePaths.jobs), isNull);
        }
      });
    });
  });
}
