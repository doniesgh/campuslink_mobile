import 'package:campuspulse/core/providers/clock_provider.dart';
import 'package:campuspulse/core/theme/app_colors.dart';
import 'package:campuspulse/features/courses/data/repositories/mock_course_repository.dart';
import 'package:campuspulse/features/courses/presentation/pages/courses_page.dart';
import 'package:campuspulse/features/courses/presentation/providers/course_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 5, 9); // Thursday

/// AppTheme needs Google Fonts (network); this keeps what matters for
/// layout: the scheme and the full-width button minimum size.
ThemeData _theme(Brightness brightness) => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: brightness)
          .copyWith(secondary: AppColors.secondary, onSecondary: AppColors.onSecondary),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      ),
    );

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        courseRepositoryProvider.overrideWithValue(
          MockCourseRepository(latency: Duration.zero, clock: () => _now),
        ),
        clockProvider.overrideWith((ref) => Stream.value(_now)),
      ],
      child: MaterialApp(
        theme: _theme(brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const CoursesPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Builds [finder] (scrollUntilVisible stops once it is in the cache extent),
/// then brings it on screen.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the Génie Logiciel course from the design', (tester) async {
    await _pump(tester);

    expect(find.text('Timetable'), findsOneWidget);
    expect(find.text('GLA-401 • Block 2B'), findsOneWidget);
    expect(find.text('Génie Logiciel & Architecture'), findsOneWidget);
    expect(find.text('Present'), findsOneWidget);
    expect(find.text('Prof. Ben Ali'), findsOneWidget);
    expect(find.text('10 / 14 Modules'), findsOneWidget);
    expect(find.text('72%'), findsOneWidget);
    expect(find.text('Completed ahead of schedule'), findsOneWidget);
    expect(find.text('Next quiz in 4 days (Arch Microservices)'), findsOneWidget);

    await _scrollTo(tester, find.text('Due Fri 23:59'));
    expect(find.text('3 files'), findsOneWidget);
    await _scrollTo(tester, find.text('24 classmates online right now'));
    expect(find.text('+8'), findsOneWidget);
    await _scrollTo(tester, find.text('Join Course Discord & Forum'));
    expect(find.text('Attendance Logged (Tap to Undo)'), findsOneWidget);
  });

  testWidgets('attendance can be undone', (tester) async {
    await _pump(tester);
    await _scrollTo(tester, find.text('Join Course Discord & Forum'));
    await tester.tap(find.text('Attendance Logged (Tap to Undo)'));
    await tester.pumpAndSettle();

    expect(find.text('Mark as Present Now'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await tester.pumpAndSettle();
    expect(find.text('Absent'), findsOneWidget);
  });

  testWidgets('a handout can be downloaded', (tester) async {
    await _pump(tester);
    await _scrollTo(tester, find.text('Get'));
    await tester.tap(find.text('Get'));
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('the code pill switches course', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('GLA-401 • Block 2B'));
    await tester.pumpAndSettle();
    expect(find.text('Your courses'), findsOneWidget);

    await tester.tap(find.text('Bases de Données'));
    await tester.pumpAndSettle();
    expect(find.text('BDD-303 • Salle 208'), findsOneWidget);
    expect(find.text('Bases de Données'), findsOneWidget);
    expect(find.text('Absent'), findsOneWidget);
    expect(find.text('Behind schedule, time to catch up'), findsOneWidget);
    expect(find.textContaining('Next quiz'), findsNothing);
  });

  testWidgets('the mastery card opens the module list', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('10 / 14 Modules'));
    await tester.pumpAndSettle();
    expect(find.text('36 of 50 teaching hours covered • Completed ahead of schedule'),
        findsOneWidget);
    expect(find.text('Up next'), findsOneWidget);
    expect(find.text('Docker Orchestration'), findsOneWidget);
  });

  testWidgets('a lab repository can be submitted', (tester) async {
    await _pump(tester);
    await _scrollTo(tester, find.text('Submit Repo'));
    await tester.tap(find.text('Submit Repo'));
    await tester.pumpAndSettle();

    final sheetButton = find.widgetWithText(FilledButton, 'Submit Repo').last;
    await tester.enterText(find.byType(TextFormField), 'github.com/me/lab');
    await tester.tap(sheetButton);
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid https:// repository link'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'https://github.com/me/docker-lab');
    await tester.tap(sheetButton);
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Submitted'), findsOneWidget);
    expect(find.text('Resubmit'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('no overflow on a small phone with large text ($brightness)', (tester) async {
      await _pump(tester, size: const Size(320, 640), textScale: 1.6, brightness: brightness);
      await _scrollTo(tester, find.text('Join Course Discord & Forum'));

      await tester.drag(find.byType(Scrollable).first, const Offset(0, 5000));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('GLA-401'));
      await tester.pumpAndSettle();
      expect(find.text('Your courses'), findsOneWidget);
      await tester.tap(find.text('Algorithmes & Complexité'));
      await tester.pumpAndSettle();
      expect(find.text('ALG-302 • Lab 14'), findsOneWidget);

      await _scrollTo(tester, find.text('6 / 12 Modules'));
      await tester.tap(find.text('6 / 12 Modules'));
      await tester.pumpAndSettle();
      expect(find.text('6 / 12 modules'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Shortest Paths'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Up next'), findsOneWidget);
    });
  }
}
