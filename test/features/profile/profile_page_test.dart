import 'package:campuspulse/core/error/failures.dart';
import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/core/providers/theme_provider.dart';
import 'package:campuspulse/core/router/route_names.dart';
import 'package:campuspulse/core/theme/app_colors.dart';
import 'package:campuspulse/features/admin/data/repositories/mock_admin_repository.dart';
import 'package:campuspulse/features/admin/presentation/providers/admin_providers.dart';
import 'package:campuspulse/features/auth/domain/entities/user.dart';
import 'package:campuspulse/features/auth/presentation/providers/auth_controller.dart';
import 'package:campuspulse/features/profile/data/repositories/mock_profile_repository.dart';
import 'package:campuspulse/features/profile/domain/entities/student_profile.dart';
import 'package:campuspulse/features/profile/domain/repositories/profile_repository.dart';
import 'package:campuspulse/features/profile/presentation/pages/profile_page.dart';
import 'package:campuspulse/features/profile/presentation/providers/profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeAuthController extends AuthController {
  _FakeAuthController({this.role = UserRole.student});

  final UserRole role;
  bool loggedOut = false;

  @override
  Future<User?> build() async => User(
        id: 'u1',
        email: 'dony.bensalem@esprit.tn',
        displayName: 'Dony Ben Salem',
        isEmailVerified: true,
        role: role,
      );

  @override
  Future<void> logout() async {
    loggedOut = true;
    state = const AsyncData(null);
  }
}

/// Avoids SharedPreferences.
class _FakeThemeModeNotifier extends ThemeModeNotifier {
  @override
  ThemeMode build() => ThemeMode.system;

  @override
  void set(ThemeMode mode) => state = mode;
}

class _FailingProfileRepository implements ProfileRepository {
  @override
  Future<Result<StudentProfile>> getMyProfile() async => const Err(ServerFailure());
}

Future<_FakeAuthController> _pumpProfile(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  ProfileRepository? repository,
  double width = 375,
  double textScale = 1,
  UserRole role = UserRole.student,
}) async {
  // 375 dp by default: the test font is much wider than the real ones, and the
  // shared CampusHeader overflows below that width with it.
  tester.view.physicalSize = Size(width, 780) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final auth = _FakeAuthController(role: role);
  Widget screen(String label) =>
      Scaffold(appBar: AppBar(), body: Center(child: Text(label)));
  final router = GoRouter(
    initialLocation: RoutePaths.profile,
    routes: [
      GoRoute(
        path: RoutePaths.profile,
        builder: (_, __) => const ProfilePage(),
        routes: [
          GoRoute(path: 'grades', builder: (_, __) => screen('Grades screen')),
          GoRoute(path: 'admin/users', builder: (_, __) => screen('Users screen')),
          GoRoute(path: 'admin/audit', builder: (_, __) => screen('Audit screen')),
        ],
      ),
      GoRoute(path: RoutePaths.notifications, builder: (_, __) => screen('Notifications screen')),
      GoRoute(path: RoutePaths.forum, builder: (_, __) => screen('Forum screen')),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => auth),
        themeModeProvider.overrideWith(_FakeThemeModeNotifier.new),
        adminRepositoryProvider.overrideWithValue(MockAdminRepository(delay: Duration.zero)),
        profileRepositoryProvider.overrideWithValue(
          repository ??
              MockProfileRepository(
                latency: Duration.zero,
                clock: () => DateTime(2026, 11, 5),
              ),
        ),
      ],
      child: MaterialApp.router(
        // Plain theme: the app theme pulls Google Fonts from the network.
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            brightness: brightness,
          ),
        ),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
  return auth;
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('renders the profile and digital ID at phone width ($brightness)',
        (tester) async {
      await _pumpProfile(tester, brightness: brightness);

      expect(find.text('Dony Ben Salem'), findsOneWidget);
      expect(find.text('Software Engineering (4BI) · ESPRIT Ghazela'), findsOneWidget);
      expect(find.text('NFC Student Pass'), findsOneWidget);
      expect(find.text('3.72'), findsOneWidget);
      expect(find.text('Top 5%'), findsOneWidget);
      expect(find.text('211JMT0428'), findsOneWidget);
      expect(find.text('DONY BEN SALEM'), findsOneWidget);
      expect(find.text('Software Eng. · Sem 7'), findsOneWidget);
      expect(find.text('2026–2027'), findsOneWidget);
      expect(find.text('Active Student'), findsOneWidget);
      expect(find.text('S7'), findsOneWidget);
      expect(find.text('3 new'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('survives a large text scale', (tester) async {
    await _pumpProfile(tester, width: 440, textScale: 1.3);
    expect(find.text('211JMT0428'), findsOneWidget);
    await tester.ensureVisible(find.text('Sign Out'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('theme selector changes the theme mode', (tester) async {
    await _pumpProfile(tester);
    final container = ProviderScope.containerOf(tester.element(find.byType(ProfilePage)));

    await _tapVisible(tester, find.byTooltip('Dark'));
    expect(container.read(themeModeProvider), ThemeMode.dark);

    await _tapVisible(tester, find.byTooltip('Light'));
    expect(container.read(themeModeProvider), ThemeMode.light);

    await _tapVisible(tester, find.byTooltip('System'));
    expect(container.read(themeModeProvider), ThemeMode.system);
  });

  testWidgets('sign out asks for confirmation, then logs out', (tester) async {
    final auth = await _pumpProfile(tester);

    await _tapVisible(tester, find.text('Sign Out'));
    expect(find.text('Are you sure you want to log out of CampusPulse?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(auth.loggedOut, isFalse);

    await _tapVisible(tester, find.text('Sign Out'));
    await tester.tap(find.widgetWithText(TextButton, 'Sign Out'));
    await tester.pumpAndSettle();
    expect(auth.loggedOut, isTrue);
  });

  testWidgets('academic curriculum and stats open grades', (tester) async {
    await _pumpProfile(tester);
    await _tapVisible(tester, find.text('My Academic Curriculum'));
    expect(find.text('Grades screen'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('3.72'));
    expect(find.text('Grades screen'), findsOneWidget);
  });

  testWidgets('notifications row opens notifications', (tester) async {
    await _pumpProfile(tester);
    await _tapVisible(tester, find.text('Notifications & Alerts'));
    expect(find.text('Notifications screen'), findsOneWidget);
  });

  testWidgets('controls without a backend show a coming-soon snack', (tester) async {
    await _pumpProfile(tester);
    await _tapVisible(tester, find.text('Edit'));
    expect(find.text('Profile editing is coming soon.'), findsOneWidget);
  });

  testWidgets('profile error keeps the settings and sign out usable', (tester) async {
    final auth = await _pumpProfile(tester, repository: _FailingProfileRepository());

    expect(find.text(const ServerFailure().message), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Dony Ben Salem'), findsOneWidget);

    await _tapVisible(tester, find.text('Sign Out'));
    await tester.tap(find.widgetWithText(TextButton, 'Sign Out'));
    await tester.pumpAndSettle();
    expect(auth.loggedOut, isTrue);
  });

  group('roles', () {
    testWidgets('a student sees no Administration section', (tester) async {
      await _pumpProfile(tester);
      expect(find.text('Administration'), findsNothing);
    });

    for (final brightness in Brightness.values) {
      testWidgets('an admin gets Administration instead of the student card ($brightness)',
          (tester) async {
        await _pumpProfile(
          tester,
          role: UserRole.admin,
          brightness: brightness,
          width: 360,
          textScale: 1.3,
        );

        expect(find.text('Admin · CampusPulse'), findsOneWidget);
        expect(find.text('Administration'), findsOneWidget);
        // The 12 demo accounts of the mock repository.
        expect(find.text('12'), findsOneWidget);
        expect(find.text('211JMT0428'), findsNothing);
        expect(find.text('NFC Student Pass'), findsNothing);
        expect(find.text('Sign Out'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Administration rows open the users and the audit log', (tester) async {
      await _pumpProfile(tester, role: UserRole.admin);
      await _tapVisible(tester, find.text('Users'));
      expect(find.text('Users screen'), findsOneWidget);

      await _pumpProfile(tester, role: UserRole.admin);
      await _tapVisible(tester, find.text('Audit log'));
      expect(find.text('Audit screen'), findsOneWidget);
    });

    testWidgets('a teacher sees neither the student card nor Administration', (tester) async {
      await _pumpProfile(tester, role: UserRole.teacher);
      expect(find.text('Teacher · CampusPulse'), findsOneWidget);
      expect(find.text('211JMT0428'), findsNothing);
      expect(find.text('Administration'), findsNothing);
    });
  });
}
