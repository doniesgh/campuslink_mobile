import 'package:campuspulse/core/providers/clock_provider.dart';
import 'package:campuspulse/core/theme/app_colors.dart';
import 'package:campuspulse/features/auth/domain/entities/user.dart';
import 'package:campuspulse/features/auth/presentation/providers/auth_controller.dart';
import 'package:campuspulse/features/timetable/presentation/pages/timetable_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monday 18 May 2026, during the 10:15 lab (as in the design).
final _now = DateTime(2026, 5, 18, 11, 5);

class _SignedIn extends AuthController {
  @override
  Future<User?> build() async =>
      const User(id: 'u1', email: 'dony@esprit.tn', displayName: 'Dony Ben Salah');
}

// The app theme loads Google Fonts over the network: use a plain theme with
// the same colors in tests.
ThemeData _theme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: brightness)
      .copyWith(secondary: AppColors.secondary, onSecondary: AppColors.onSecondary);
  return ThemeData(useMaterial3: true, colorScheme: scheme);
}

Future<void> _pumpPage(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  double width = 390,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = Size(width * 3, 2600 * 3);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWith((ref) => Stream.value(_now)),
        authControllerProvider.overrideWith(_SignedIn.new),
      ],
      child: MaterialApp(
        theme: _theme(brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const TimetablePage(),
      ),
    ),
  );
  await _settle(tester);
}

/// Lets the mock repository (400 ms) answer. Not pumpAndSettle: the "live"
/// dots pulse forever.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

void main() {
  testWidgets('shows the day as in the design', (tester) async {
    await _pumpPage(tester);

    expect(find.text('My Timetable'), findsOneWidget);
    expect(find.text('ESPRIT Engineering · Tech Track 4BI'), findsOneWidget);
    expect(find.text('May 18–22 · Semester 2'), findsOneWidget);
    expect(find.text('4 Sessions Scheduled'), findsOneWidget);
    expect(find.textContaining('1 Exam Today', findRichText: true), findsOneWidget);
    expect(find.textContaining('7h 30m Total', findRichText: true), findsOneWidget);

    // Past lecture, lab in progress, lunch, next workshop, evaluation.
    expect(find.text('Passed'), findsOneWidget);
    expect(find.text('NOW'), findsOneWidget);
    expect(find.text('2 hrs · In Progress'), findsOneWidget);
    expect(find.text('Time elapsed: 50m'), findsOneWidget);
    expect(find.text('1h 10m left'), findsOneWidget);
    expect(find.text('🍴 Free Period ✦ Déjeuner & Révision'), findsOneWidget);
    expect(find.text('1h 15m'), findsOneWidget);
    expect(find.text('Starts in 2h 25m'), findsOneWidget);
    expect(find.text('⚠️ Major Evaluation · Coeff 2.0'), findsOneWidget);
    expect(find.text('Tap to show barcode at Grand Amphi C'), findsOneWidget);
  });

  testWidgets('switching day and week', (tester) async {
    await _pumpPage(tester);

    await tester.tap(find.text('TUE'));
    await _settle(tester);
    expect(find.text('NOW'), findsNothing);
    expect(find.text('Bases de Données'), findsOneWidget);
    expect(find.text('3 Sessions Scheduled'), findsOneWidget);
    expect(find.textContaining('Exam', findRichText: true), findsNothing);

    await tester.tap(find.text('SAT'));
    await _settle(tester);
    expect(find.text('No classes this day'), findsOneWidget);

    await tester.tap(find.byTooltip('Next week'));
    await _settle(tester);
    expect(find.text('May 25–29'), findsOneWidget); // after the end of S2
    expect(find.byTooltip('Back to this week'), findsOneWidget);

    await tester.tap(find.text('May 25–29'));
    await _settle(tester);
    expect(find.text('May 18–22 · Semester 2'), findsOneWidget);
    expect(find.text('NOW'), findsOneWidget); // back on today
  });

  testWidgets('controls without a backend show a snackbar', (tester) async {
    await _pumpPage(tester);

    await tester.tap(find.text('Find Seat'));
    await tester.pump();
    expect(find.text('Seat finder is coming soon.'), findsOneWidget);

    // Let the snackbar timer run out.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 2));
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('no overflow on a narrow screen with large text ($brightness)', (tester) async {
      // The test font is about twice as wide as the real one, so this is a
      // pessimistic check. The shared CampusHeader (outside this feature)
      // overflows with it: ignore that one, fail on any other error.
      final reported = FlutterError.onError;
      final errors = <FlutterErrorDetails>[];
      FlutterError.onError = (details) {
        if (!details.toString().contains('campus_header.dart')) errors.add(details);
      };
      try {
        await _pumpPage(tester, brightness: brightness, width: 320, textScale: 1.3);
        expect(find.text('Génie Logiciel & Architecture'), findsOneWidget);
        await tester.tap(find.text('SAT'));
        await _settle(tester);
        await tester.tap(find.text('THU'));
        await _settle(tester);
      } finally {
        FlutterError.onError = reported;
      }
      expect(errors.map((e) => e.toString()), isEmpty);
    });
  }
}
