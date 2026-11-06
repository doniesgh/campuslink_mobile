import 'package:campuspulse/core/providers/clock_provider.dart';
import 'package:campuspulse/core/router/route_names.dart';
import 'package:campuspulse/core/theme/app_colors.dart';
import 'package:campuspulse/features/auth/domain/entities/user.dart';
import 'package:campuspulse/features/auth/presentation/providers/auth_controller.dart';
import 'package:campuspulse/features/notifications/data/repositories/mock_notification_repository.dart';
import 'package:campuspulse/features/notifications/presentation/pages/notifications_page.dart';
import 'package:campuspulse/features/notifications/presentation/providers/notification_providers.dart';
import 'package:campuspulse/features/notifications/presentation/widgets/notification_filter_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final _now = DateTime(2026, 11, 5, 10, 30);

class _SignedIn extends AuthController {
  @override
  Future<User?> build() async => const User(
        id: 'u1',
        email: 'dony@esprit.tn',
        displayName: 'Dony Student',
        isEmailVerified: true,
      );
}

Widget _stub(String label) => Scaffold(body: Center(child: Text(label)));

Future<void> _pumpPage(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  double width = 320,
  double textScale = 1.3,
}) async {
  tester.view
    // Tall enough for the whole (lazy) list to be built and checked for overflows.
    ..physicalSize = Size(width, 12000)
    ..devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final router = GoRouter(
    initialLocation: RoutePaths.notifications,
    routes: [
      GoRoute(path: RoutePaths.notifications, builder: (_, __) => const NotificationsPage()),
      GoRoute(path: RoutePaths.home, builder: (_, __) => _stub('HOME')),
      GoRoute(path: RoutePaths.timetable, builder: (_, __) => _stub('TIMETABLE')),
      GoRoute(
        path: RoutePaths.forum,
        builder: (_, __) => _stub('FORUM'),
        routes: [
          GoRoute(
            path: 'rides/:id',
            builder: (_, state) => _stub('RIDE ${state.pathParameters['id']}'),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(
          MockNotificationRepository(clock: () => _now, latency: Duration.zero),
        ),
        clockProvider.overrideWith((ref) => Stream.value(_now)),
        authControllerProvider.overrideWith(_SignedIn.new),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            brightness: brightness,
          ),
        ),
      ),
    ),
  );
  // Load the notifications, then let the clock emit.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  // The feed's first frame uses the real DateTime.now(): rebuild it with the
  // frozen clock, or the "today" texts depend on the day the test runs.
  await tester.pump();
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('renders the design on a narrow screen with large text ($brightness)',
        (tester) async {
      await _pumpPage(tester, brightness: brightness);

      expect(tester.takeException(), isNull);
      expect(find.text('Campus Alerts'), findsOneWidget);
      expect(find.text('2 critical campus updates today'), findsOneWidget);
      expect(find.text('Mark all read'), findsOneWidget);
      expect(find.text('BROADCAST NETWORK'), findsOneWidget);
      expect(find.text('Room Change: Génie Logiciel'), findsOneWidget);
      expect(find.text('View Trip Details'), findsOneWidget);
      expect(find.text('Hier · 14:30'), findsOneWidget);
      expect(find.text('Claim ticket #492'), findsOneWidget);
      for (final header in ['TODAY', 'YESTERDAY', 'EARLIER']) {
        expect(find.text(header), findsOneWidget);
      }
      expect(find.text('Manage Notification Preferences'), findsOneWidget);
    });
  }

  testWidgets('renders on a regular phone width', (tester) async {
    await _pumpPage(tester, width: 412, textScale: 1);
    expect(tester.takeException(), isNull);
    expect(find.text('View Trip Details'), findsOneWidget);
  });

  testWidgets('filters by chip', (tester) async {
    await _pumpPage(tester);

    Future<void> tapChip(String label) async {
      // The chips scroll horizontally: bring the chip on screen first.
      final chip = find.descendant(
        of: find.byType(NotificationFilterBar),
        matching: find.text(label),
      );
      await tester.ensureVisible(chip);
      await tester.pump();
      await tester.tap(chip);
      await tester.pump();
    }

    await tapChip('Urgent Alerts');
    expect(find.text('Room Change: Génie Logiciel'), findsOneWidget);
    expect(find.text('Potential match for your lost item'), findsOneWidget);
    expect(find.text('Ride Booking Confirmed with Sarra K.'), findsNothing);

    await tapChip('Covoiturage');
    expect(find.text('Ride Booking Confirmed with Sarra K.'), findsOneWidget);
    expect(find.text('Room Change: Génie Logiciel'), findsNothing);
  });

  testWidgets('mark all read', (tester) async {
    await _pumpPage(tester);

    await tester.tap(find.text('Mark all read'));
    await tester.pump(); // optimistic update
    expect(find.text('All Read'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 10)); // repository call

    expect(find.text('All Read'), findsOneWidget);
    expect(find.text("You're all caught up today"), findsOneWidget);
    final container = ProviderScope.containerOf(tester.element(find.byType(NotificationsPage)));
    expect(container.read(unreadNotificationCountProvider), 0);
  });

  testWidgets('tapping a ride notification opens the ride', (tester) async {
    await _pumpPage(tester);

    await tester.tap(find.text('Ride Booking Confirmed with Sarra K.'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('RIDE es-4091'), findsOneWidget);
  });

  testWidgets('coming-soon actions show a snackbar', (tester) async {
    await _pumpPage(tester);

    await tester.tap(find.text('Map pin'));
    await tester.pump();
    expect(find.text('Campus map is coming soon.'), findsOneWidget);
  });
}
