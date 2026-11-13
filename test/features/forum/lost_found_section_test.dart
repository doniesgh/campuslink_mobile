import 'package:campuspulse/core/providers/clock_provider.dart';
import 'package:campuspulse/core/theme/app_colors.dart';
import 'package:campuspulse/features/forum/presentation/widgets/lost_found_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Same colors and button sizing as AppTheme, without Google Fonts
/// (they would be downloaded at runtime).
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
  String query = '',
  VoidCallback? onClearSearch,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  Size size = const Size(360, 3200),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [clockProvider.overrideWith((ref) => Stream.value(DateTime.now()))],
      child: MaterialApp(
        theme: _theme(brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: LostFoundSection(query: query, onClearSearch: onClearSearch ?? () {}),
        ),
      ),
    ),
  );
  // MockForumRepository latency.
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

/// The count bubble of the filter pill labelled [label].
Finder _pillCount(String label, int count) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first,
      matching: find.text('$count'),
    );

Future<void> _tapPill(WidgetTester tester, String label) async {
  // The pills scroll horizontally on narrow screens.
  await tester.ensureVisible(find.text(label));
  await tester.pump();
  await tester.tap(find.text(label));
  await tester.pump();
}

void main() {
  testWidgets('shows the board with the filter counts', (tester) async {
    await _pump(tester);

    expect(find.text('Objets Perdus & Trouvés'), findsOneWidget);
    expect(find.text('Point de collecte central'), findsOneWidget);
    expect(find.text('Calculatrice TI-84 Plus CE'), findsOneWidget);
    expect(find.text('Clés Peugeot + Porte-clé ESPRIT'), findsOneWidget);
    expect(find.text("C'est à moi / Réclamer"), findsWidgets);
    expect(find.text("J'ai trouvé cet objet !"), findsWidgets);
    expect(find.text('Vérifier le numéro de série'), findsOneWidget);
    expect(find.text('Conseil étudiant'), findsOneWidget);
    expect(_pillCount('Tous', 7), findsOneWidget);
    expect(_pillCount('Objets Perdus', 4), findsOneWidget);
    expect(_pillCount('Objets Trouvés', 3), findsOneWidget);
  });

  testWidgets('the kind pills filter the list', (tester) async {
    await _pump(tester);

    await _tapPill(tester, 'Objets Perdus');
    expect(find.text('Clés Peugeot + Porte-clé ESPRIT'), findsOneWidget);
    expect(find.text('Calculatrice TI-84 Plus CE'), findsNothing);

    await _tapPill(tester, 'Objets Trouvés');
    expect(find.text('Calculatrice TI-84 Plus CE'), findsOneWidget);
    expect(find.text('Clés Peugeot + Porte-clé ESPRIT'), findsNothing);
  });

  testWidgets('the forum search query filters the items and the counts', (tester) async {
    await _pump(tester, query: 'parking');

    expect(find.text('Clés Peugeot + Porte-clé ESPRIT'), findsOneWidget);
    expect(find.text('Calculatrice TI-84 Plus CE'), findsNothing);
    expect(_pillCount('Tous', 1), findsOneWidget);
    expect(_pillCount('Objets Perdus', 1), findsOneWidget);
    expect(_pillCount('Objets Trouvés', 0), findsOneWidget);
  });

  testWidgets('no match shows the empty state and resets the search', (tester) async {
    var cleared = 0;
    await _pump(tester, query: 'parapluie', onClearSearch: () => cleared++);

    expect(find.text('Aucun objet correspondant'), findsOneWidget);
    await tester.tap(find.text('Réinitialiser la recherche'));
    await tester.pump();
    expect(cleared, 1);
  });

  testWidgets('claiming an item sends the request and confirms it', (tester) async {
    await _pump(tester);

    await tester.tap(find.text("C'est à moi / Réclamer").first);
    await tester.pumpAndSettle();
    expect(find.text('Réclamer: Calculatrice TI-84 Plus CE'), findsOneWidget);

    final submit = find.text('Envoyer ma demande de réclamation');
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Réclamer: Calculatrice TI-84 Plus CE'), findsOneWidget); // disabled

    await tester.enterText(find.byType(TextField), 'Autocollant ESPRIT au dos');
    await tester.pump();
    await tester.tap(submit);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Réclamer: Calculatrice TI-84 Plus CE'), findsNothing);
    expect(find.text('Signalement transmis au staff de sécurité !'), findsOneWidget);

    // Let the snackbar time out.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  for (final brightness in Brightness.values) {
    testWidgets('lays out without overflow at a large font size ($brightness)', (tester) async {
      await _pump(tester, brightness: brightness, textScale: 2, size: const Size(320, 5200));
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Vérifier le numéro de série'));
      await tester.pumpAndSettle();
      expect(find.text('Vérification Numéro de Série'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
