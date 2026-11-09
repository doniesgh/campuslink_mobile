import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/core/providers/clock_provider.dart';
import 'package:campuspulse/core/providers/theme_provider.dart';
import 'package:campuspulse/core/router/app_router.dart';
import 'package:campuspulse/core/theme/app_colors.dart';
import 'package:campuspulse/features/admin/data/repositories/mock_admin_repository.dart';
import 'package:campuspulse/features/admin/presentation/pages/admin_users_page.dart';
import 'package:campuspulse/features/admin/presentation/providers/admin_providers.dart';
import 'package:campuspulse/features/auth/domain/entities/user.dart';
import 'package:campuspulse/features/auth/presentation/providers/auth_controller.dart';
import 'package:campuspulse/features/forum/domain/entities/forum_post.dart';
import 'package:campuspulse/features/forum/domain/repositories/forum_repository.dart';
import 'package:campuspulse/features/forum/presentation/providers/forum_providers.dart';
import 'package:campuspulse/features/home/presentation/pages/home_page.dart';
import 'package:campuspulse/features/notifications/data/repositories/mock_notification_repository.dart';
import 'package:campuspulse/features/notifications/presentation/providers/notification_providers.dart';
import 'package:campuspulse/features/profile/data/repositories/mock_profile_repository.dart';
import 'package:campuspulse/features/profile/presentation/providers/profile_providers.dart';
import 'package:campuspulse/features/timetable/domain/entities/class_session.dart';
import 'package:campuspulse/features/timetable/domain/entities/timetable_week.dart';
import 'package:campuspulse/features/timetable/domain/repositories/timetable_repository.dart';
import 'package:campuspulse/features/timetable/presentation/providers/timetable_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthController extends AuthController {
  _FakeAuthController(this.role);

  final UserRole role;

  @override
  Future<User?> build() async => User(
        id: 'u1',
        email: 'someone@campus.test',
        displayName: 'Sam Example',
        isEmailVerified: true,
        role: role,
      );
}

/// Avoids SharedPreferences.
class _FakeThemeModeNotifier extends ThemeModeNotifier {
  @override
  ThemeMode build() => ThemeMode.system;

  @override
  void set(ThemeMode mode) => state = mode;
}

/// Counts the timetable requests: admins and alumni must not make any.
class _CountingTimetableRepository implements TimetableRepository {
  int calls = 0;

  @override
  Future<Result<TimetableDay>> getDay(DateTime day) async {
    calls++;
    return Success(TimetableDay(date: day, sessions: const [], semesterWeek: 8));
  }

  @override
  Future<Result<TimetableWeek>> getWeek(DateTime day) async {
    calls++;
    throw UnimplementedError();
  }
}

/// No highlights; Home uses nothing else of the forum.
class _QuietForumRepository implements ForumRepository {
  @override
  Future<Result<List<ForumPost>>> getHighlights() async => const Success([]);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// The whole app (real router, tabs and Home) signed in as [role].
Future<_CountingTimetableRepository> _pumpApp(
  WidgetTester tester,
  UserRole role, {
  Brightness brightness = Brightness.light,
  double width = 375,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 780) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final timetable = _CountingTimetableRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => _FakeAuthController(role)),
        themeModeProvider.overrideWith(_FakeThemeModeNotifier.new),
        clockProvider.overrideWith((ref) => Stream.value(DateTime(2026, 11, 9, 9))),
        timetableRepositoryProvider.overrideWithValue(timetable),
        forumRepositoryProvider.overrideWithValue(_QuietForumRepository()),
        notificationRepositoryProvider
            .overrideWithValue(MockNotificationRepository(latency: Duration.zero)),
        adminRepositoryProvider.overrideWithValue(MockAdminRepository(delay: Duration.zero)),
        profileRepositoryProvider.overrideWithValue(
          MockProfileRepository(latency: Duration.zero, clock: () => DateTime(2026, 11, 9)),
        ),
      ],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          // Plain theme: the app theme pulls Google Fonts from the network.
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: brightness),
          ),
          routerConfig: ref.watch(routerProvider),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
  expect(find.byType(HomePage), findsOneWidget);
  return timetable;
}

List<String> _tabLabels(WidgetTester tester) => [
      for (final d in tester.widgetList<NavigationDestination>(find.byType(NavigationDestination)))
        d.label,
    ];

int _selectedTab(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

void main() {
  for (final role in [UserRole.student, UserRole.teacher]) {
    testWidgets('a ${role.name} has the Timetable tab and today\'s classes', (tester) async {
      final timetable = await _pumpApp(tester, role);

      expect(_tabLabels(tester), ['Home', 'Timetable', 'Forum', 'Jobs', 'Profile']);
      expect(find.text("Today's Schedule"), findsOneWidget);
      expect(find.text('Planning'), findsOneWidget);
      expect(find.text('Administration'), findsNothing);
      expect(timetable.calls, greaterThan(0));
    });
  }

  group('an admin has no timetable', () {
    testWidgets('no tab, no classes on Home, the Administration card instead', (tester) async {
      final timetable = await _pumpApp(tester, UserRole.admin);

      expect(_tabLabels(tester), ['Home', 'Forum', 'Jobs', 'Profile']);
      expect(find.text("Today's Schedule"), findsNothing);
      expect(find.text('Planning'), findsNothing);
      expect(find.text('Administration'), findsOneWidget);
      // The 12 demo accounts of the mock repository.
      expect(find.text('12 accounts on CampusPulse'), findsOneWidget);
      expect(find.text('Comptes'), findsOneWidget);
      expect(timetable.calls, 0);
    });

    testWidgets('"Comptes" opens the users, on the Profile tab', (tester) async {
      await _pumpApp(tester, UserRole.admin);

      await tester.tap(find.text('Comptes'));
      await tester.pumpAndSettle();

      expect(find.byType(AdminUsersPage), findsOneWidget);
      expect(_selectedTab(tester), 3); // Profile, with the Timetable tab gone.
    });

    for (final brightness in Brightness.values) {
      testWidgets('Home fits at 360 dp with large text ($brightness)', (tester) async {
        await _pumpApp(
          tester,
          UserRole.admin,
          brightness: brightness,
          width: 360,
          textScale: 1.3,
        );

        await tester.ensureVisible(find.text('Audit log'));
        await tester.pumpAndSettle();
        expect(find.text('Students'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('an alumni has no timetable and no Administration', (tester) async {
    final timetable = await _pumpApp(tester, UserRole.alumni);

    expect(_tabLabels(tester), ['Home', 'Forum', 'Jobs', 'Profile']);
    expect(find.text("Today's Schedule"), findsNothing);
    expect(find.text('Administration'), findsNothing);
    expect(find.text('Offres'), findsOneWidget);
    expect(timetable.calls, 0);
  });
}
