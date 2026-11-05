import 'package:campuspulse/core/providers/clock_provider.dart';
import 'package:campuspulse/core/theme/app_colors.dart';
import 'package:campuspulse/features/grades/data/repositories/mock_grades_repository.dart';
import 'package:campuspulse/features/grades/presentation/pages/grades_page.dart';
import 'package:campuspulse/features/grades/presentation/providers/grades_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixed date (4th year, current S7) so the published semesters are always
/// Sem 6, 5 and 4 whatever today's date is.
final _now = DateTime(2026, 11, 5, 10);

/// Plain Material theme (the app theme loads Google Fonts over the network).
Widget _app({double textScale = 1, Brightness brightness = Brightness.light}) => ProviderScope(
      overrides: [
        gradesRepositoryProvider.overrideWithValue(
          MockGradesRepository(latency: Duration.zero, clock: () => _now),
        ),
        clockProvider.overrideWith((ref) => Stream.value(_now)),
      ],
      child: MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            brightness: brightness,
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const GradesPage(),
      ),
    );

Future<void> _pumpPage(WidgetTester tester, {double width = 390, double textScale = 1}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = Size(width * 2, 844 * 2);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(textScale: textScale));
  await tester.pump(const Duration(milliseconds: 10));
  await tester.pumpAndSettle();
}

final _list = find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
);

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: _list);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the latest semester with computed averages', (tester) async {
    await _pumpPage(tester);

    expect(find.text('Profile'), findsOneWidget); // back pill
    expect(find.text('2025–2026 · Sem 6'), findsOneWidget);
    expect(find.text('ID: CP-2024-8891'), findsOneWidget);
    expect(find.text('Official Record'), findsOneWidget);
    expect(find.text('Top 5% Cohort'), findsOneWidget);

    expect(find.text('ACADEMIC EXCELLENCE'), findsOneWidget);
    expect(find.text('Updated 2h ago'), findsOneWidget);
    expect(find.text('SEMESTER 6 STANDING'), findsOneWidget);
    expect(find.text('Excellent'), findsOneWidget);
    expect(find.text('« Mention Très Bien »'), findsOneWidget);
    expect(find.text('16.57'), findsOneWidget);
    expect(find.text('83%'), findsOneWidget);
    expect(find.text('30 / 30 ECTS'), findsOneWidget);
    expect(find.text('+0.35 pts'), findsOneWidget);

    expect(find.text('Module Breakdown'), findsOneWidget);
    expect(find.text('4 Courses'), findsOneWidget);
    expect(find.text('Génie Logiciel & Microservices'), findsOneWidget);
    expect(find.text('Validé (A)'), findsWidgets);
    expect(find.text('16.60/20', findRichText: true), findsOneWidget);

    await _scrollTo(tester, find.text('Anglais Pro & Soft Skills'));
    expect(find.text('Validé (A+)'), findsOneWidget);
    expect(find.text('--/20', findRichText: true), findsOneWidget); // no exam

    await _scrollTo(tester, find.text('Signed by Dean Marc Lefèvre'));
    await _scrollTo(tester, find.textContaining("tableau d'honneur du semestre 6"));
  });

  testWidgets('download shows a coming-soon snack', (tester) async {
    await _pumpPage(tester);
    final button = find.text('Télécharger le Relevé de Notes Officiel (PDF Signé)');
    await _scrollTo(tester, button);
    await tester.tap(button);
    await tester.pump();
    expect(find.text('Transcript download is coming soon.'), findsOneWidget);
  });

  testWidgets('the period selector switches semester', (tester) async {
    await _pumpPage(tester);

    await tester.tap(find.text('2025–2026 · Sem 6'));
    await tester.pumpAndSettle();
    expect(find.text('Academic period'), findsOneWidget);
    expect(find.text('16.57 / 20 · Très Bien'), findsOneWidget);
    expect(find.text('12.29 / 20 · Assez Bien'), findsOneWidget);

    await tester.tap(find.text('2024–2025 · Sem 4'));
    await tester.pumpAndSettle();

    expect(find.text('Academic period'), findsNothing);
    expect(find.text('2024–2025 · Sem 4'), findsOneWidget);
    expect(find.text('12.29'), findsOneWidget);
    expect(find.text('Good'), findsOneWidget);
    expect(find.text('« Mention Assez Bien »'), findsOneWidget);
    expect(find.text('SEMESTER VALIDATED'), findsOneWidget);
    expect(find.textContaining('pts'), findsNothing); // oldest semester: no trend
    expect(find.text('Top 35% Cohort'), findsOneWidget);

    await _scrollTo(tester, find.text('Compensé (D)'));
    await _scrollTo(tester, find.text('Signed by Dean Marc Lefèvre'));
    expect(find.textContaining("tableau d'honneur"), findsNothing);
  });

  for (final (width, scale) in [(320.0, 1.0), (360.0, 1.3), (360.0, 2.0)]) {
    testWidgets('no overflow at ${width.toInt()} px wide, text x$scale', (tester) async {
      await _pumpPage(tester, width: width, textScale: scale);
      await _scrollTo(tester, find.textContaining('Certifié conforme'));
      await tester.drag(_list, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('renders in dark mode', (tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(brightness: Brightness.dark));
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pumpAndSettle();
    expect(find.text('16.57'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
