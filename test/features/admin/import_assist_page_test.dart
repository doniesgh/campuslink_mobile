import 'package:campuspulse/core/error/failures.dart';
import 'package:campuspulse/core/router/route_names.dart';
import 'package:campuspulse/core/theme/app_colors.dart';
import 'package:campuspulse/features/admin/data/repositories/mock_admin_repository.dart';
import 'package:campuspulse/features/admin/presentation/pages/import_users_page.dart';
import 'package:campuspulse/features/admin/presentation/providers/admin_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The import screen on the mock repository (its fake AI answers at once).
Future<MockAdminRepository> _pump(
  WidgetTester tester, {
  bool assistAvailable = true,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = const Size(360, 800) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final repo = MockAdminRepository(
    delay: Duration.zero,
    now: () => DateTime(2026, 11, 13, 10),
    assistAvailable: assistAvailable,
  );
  final router = GoRouter(
    initialLocation: RoutePaths.importUsers,
    routes: [
      GoRoute(
        path: RoutePaths.profile,
        builder: (_, __) => const Scaffold(body: Center(child: Text('Profile screen'))),
        routes: [
          GoRoute(path: 'admin/import', builder: (_, __) => const ImportUsersPage()),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [adminRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(
        // Plain theme: the app theme pulls Google Fonts from the network.
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: brightness),
        ),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _paste(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await _tap(tester, find.text('Read the rows'));
}

/// No known email title, a note above the titles, full names, loose roles.
const _file = 'Liste promo 2026;;;\n'
    'Nom et prénom;Adresse;Profil;MDP\n'
    'BEN ALI Ines;ines.benali@import.test;Étudiant(e);Secret-1234\n'
    'GHARBI Ali;ali.gharbi@import.test;Enseignant vacataire;Password1\n';

Finder _button(String label) => find.widgetWithText(OutlinedButton, label);

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('reads a file that does not follow the template with AI, then undoes it '
        '($brightness)', (tester) async {
      final repo = await _pump(tester, brightness: brightness);
      await _paste(tester, _file);

      expect(
        find.text('Columns not found: Email. Put the column titles on the first line.'),
        findsOneWidget,
      );
      expect(find.text("This file doesn't follow the template. The AI can work out which column is which."),
          findsOneWidget);
      expect(find.textContaining('are sent to mock/import-assist through OpenRouter'), findsOneWidget);

      await _tap(tester, _button('Read with AI'));

      expect(find.text('Check the lines'), findsOneWidget);
      expect(find.text('2 lines'), findsOneWidget);
      expect(find.text('2 ready'), findsOneWidget);
      expect(find.text('• Titles on line 2.'), findsOneWidget);
      expect(
        find.text('• Columns: Full name A (family name first) · Email B · Role C · Password D.'),
        findsOneWidget,
      );
      expect(
        find.text('• Roles: “Étudiant(e)” → Student, “Enseignant vacataire” → Teacher.'),
        findsOneWidget,
      );
      expect(find.text('• Check how the full names were split.'), findsOneWidget);
      expect(find.text('Model: mock/import-assist'), findsOneWidget);
      expect(find.text('Line 3 · Ines BEN ALI'), findsOneWidget);
      expect(find.text('Line 4 · Ali GHARBI'), findsOneWidget);
      expect(find.textContaining('Teacher'), findsWidgets);
      expect(tester.takeException(), isNull);
      // Nothing is imported before the admin says so.
      expect((await repo.getStats()).unwrap().total, 14);

      await _tap(tester, find.text('Undo'));

      expect(find.text('Check the lines'), findsNothing);
      expect(
        find.text('Columns not found: Email. Put the column titles on the first line.'),
        findsOneWidget,
      );
      expect(_button('Read with AI'), findsOneWidget);
    });
  }

  testWidgets('the file read with AI is imported once the admin confirms', (tester) async {
    final repo = await _pump(tester);
    await _paste(tester, _file);
    await _tap(tester, _button('Read with AI'));

    await _tap(tester, find.widgetWithText(FilledButton, 'Import'));

    expect(find.text('2 accounts created.'), findsOneWidget);
    final created = (await repo.getUsers(query: 'import.test')).unwrap().items;
    expect(created.map((u) => (u.displayName, u.role.label)).toSet(), {
      ('Ines BEN ALI', 'Student'),
      ('Ali GHARBI', 'Teacher'),
    });
    final audit = (await repo.getAudit()).unwrap().items.map((e) => e.action);
    expect(audit, ['user.import', 'user.import.assist']);
  });

  testWidgets('Fix with AI reads the roles the app cannot, with Undo', (tester) async {
    await _pump(tester);
    await _paste(
      tester,
      'Name,Email,Role\n'
      'Lina Bouazizi,lina@import.test,Enseignant(e) vacataire\n'
      'Sami Kefi,sami@import.test,Étudiant\n',
    );

    expect(find.text('1 to fix'), findsOneWidget);
    expect(find.text("Some roles or names can't be read. The AI can work out what they mean."),
        findsOneWidget);

    await _tap(tester, _button('Fix with AI'));

    expect(find.text('1 to fix'), findsNothing);
    expect(find.text('2 ready'), findsOneWidget);
    expect(find.text('• Titles on line 1.'), findsOneWidget);
    expect(find.text('Line 2 · Lina Bouazizi'), findsOneWidget);
    expect(find.textContaining('“Enseignant(e) vacataire” → Teacher'), findsOneWidget);

    await _tap(tester, find.text('Undo'));

    expect(find.text('1 to fix'), findsOneWidget);
    expect(_button('Fix with AI'), findsOneWidget);
  });

  testWidgets('shows why the AI could not read the file, and imports nothing', (tester) async {
    final repo = await _pump(tester);
    repo.assistFailure = const TooManyRequestsFailure(
      'The AI service is busy. Try again in a few minutes.',
      'AI_BUSY',
    );
    await _paste(tester, _file);

    await _tap(tester, _button('Read with AI'));

    expect(find.text('The AI service is busy. Try again in a few minutes.'), findsOneWidget);
    expect(find.text('Check the lines'), findsNothing);
    expect((await repo.getStats()).unwrap().total, 14);
  });

  testWidgets('the AI is offered only when the server has one', (tester) async {
    await _pump(tester, assistAvailable: false);
    await _paste(tester, _file);

    expect(
      find.text('Columns not found: Email. Put the column titles on the first line.'),
      findsOneWidget,
    );
    expect(find.text('Read with AI'), findsNothing);
  });
}
