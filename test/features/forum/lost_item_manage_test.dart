import 'package:campuspulse/core/providers/clock_provider.dart';
import 'package:campuspulse/features/forum/presentation/widgets/lost_found_section.dart';
import 'package:campuspulse/features/forum/presentation/widgets/lost_item_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The Lost & Found board with the mock repository (USE_MOCK, the default):
// the demo student reported "lf-407" (Calculatrice graphique TI-84).

const _mine = 'Calculatrice graphique TI-84';
const _menu = "Gérer l'annonce";

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [clockProvider.overrideWith((ref) => Stream.value(DateTime.now()))],
      child: MaterialApp(
        home: Scaffold(body: LostFoundSection(query: '', onClearSearch: () {})),
      ),
    ),
  );
  await _waitForMock(tester);
}

/// MockForumRepository answers after 450 ms.
Future<void> _waitForMock(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

/// The board card titled [title].
Finder _card(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(LostItemCard)).first;

Future<void> _choose(WidgetTester tester, String entry) async {
  await tester.tap(find.byTooltip(_menu));
  await tester.pumpAndSettle();
  await tester.tap(find.text(entry));
  await tester.pumpAndSettle();
}

/// Lets the snackbar time out.
Future<void> _dismissSnack(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('only the reporter’s notice has the manage menu, and no claim action',
      (tester) async {
    await _pump(tester);

    expect(find.byTooltip(_menu), findsOneWidget);
    expect(find.descendant(of: _card(_mine), matching: find.byTooltip(_menu)), findsOneWidget);
    expect(
      find.descendant(of: _card(_mine), matching: find.text("J'ai trouvé cet objet !")),
      findsNothing,
    );
    // Every active notice offers its possible matches.
    expect(find.text('Correspondances possibles'), findsNWidgets(7));
  });

  testWidgets('marks the notice resolved, then active again', (tester) async {
    await _pump(tester);

    await _choose(tester, 'Marquer comme résolue');
    await _waitForMock(tester);
    await _waitForMock(tester); // the board reloads

    expect(find.text('Annonce marquée comme résolue.'), findsOneWidget);
    expect(
      find.descendant(
        of: _card(_mine),
        matching: find.text('Résolu · objet rendu à son propriétaire'),
      ),
      findsOneWidget,
    );
    expect(find.text('Correspondances possibles'), findsNWidgets(6));
    await _dismissSnack(tester);

    await _choose(tester, "Réactiver l'annonce");
    await _waitForMock(tester);
    await _waitForMock(tester);
    expect(find.text('Annonce réactivée.'), findsOneWidget);
    expect(find.text('Résolu · objet rendu à son propriétaire'), findsNothing);
    await _dismissSnack(tester);
  });

  testWidgets('deleting asks for confirmation first', (tester) async {
    await _pump(tester);

    await _choose(tester, 'Supprimer');
    expect(find.text("Supprimer l'annonce ?"), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.text(_mine), findsOneWidget);

    await _choose(tester, 'Supprimer');
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await tester.pump();
    await _waitForMock(tester);
    await _waitForMock(tester); // the board reloads

    expect(find.text(_mine), findsNothing);
    expect(find.text('Annonce supprimée.'), findsOneWidget);
    expect(find.byTooltip(_menu), findsNothing);
    await _dismissSnack(tester);
  });

  testWidgets('editing reuses the publish form, prefilled', (tester) async {
    await _pump(tester);

    await _choose(tester, 'Modifier');
    expect(find.text("Modifier l'annonce"), findsOneWidget);
    expect(find.widgetWithText(TextFormField, _mine), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Salle C10 (Ghazela)'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, _mine), 'Calculatrice TI-84 (étui bleu)');
    final save = find.text('Enregistrer les modifications');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await _waitForMock(tester);
    await _waitForMock(tester); // the board reloads

    expect(find.text("Modifier l'annonce"), findsNothing);
    expect(find.text('Annonce mise à jour.'), findsOneWidget);
    expect(find.text('Calculatrice TI-84 (étui bleu)'), findsOneWidget);
    expect(find.text(_mine), findsNothing);
    await _dismissSnack(tester);
  });

  testWidgets('"Correspondances possibles" shows the picked match first', (tester) async {
    await _pump(tester);

    await tester.tap(
      find.descendant(of: _card(_mine), matching: find.text('Correspondances possibles')),
    );
    await _waitForMock(tester);

    expect(find.text('Objets trouvés qui ressemblent à cette annonce.'), findsOneWidget);
    final match = find.text("Voir l'annonce ›");
    expect(match, findsOneWidget);
    expect(find.textContaining('Même catégorie', findRichText: true), findsOneWidget);

    await tester.tap(match);
    await tester.pumpAndSettle();

    expect(find.text('Correspondance sélectionnée'), findsOneWidget);
    // The found calculator, pinned above the board (and still in it).
    expect(find.text('Calculatrice TI-84 Plus CE'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(find.text('Correspondance sélectionnée'), findsNothing);
  });
}
