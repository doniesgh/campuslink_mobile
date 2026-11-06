import 'package:campuspulse/core/error/failures.dart';
import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/core/theme/app_colors.dart';
import 'package:campuspulse/features/forum/domain/entities/lost_item.dart';
import 'package:campuspulse/features/forum/domain/entities/lost_item_draft.dart';
import 'package:campuspulse/features/forum/domain/repositories/forum_repository.dart';
import 'package:campuspulse/features/forum/presentation/providers/forum_providers.dart';
import 'package:campuspulse/features/forum/presentation/widgets/lost_item_publish_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the drafts and answers like the API (or with [reply]).
class _FakeForumRepository implements ForumRepository {
  final drafts = <LostItemDraft>[];
  Result<LostItem>? reply;

  @override
  Future<Result<LostItem>> publishLostItem(LostItemDraft draft) async {
    drafts.add(draft);
    return reply ??
        Success(LostItem(
          id: 'lf-new',
          kind: draft.kind,
          title: draft.title.trim(),
          category: draft.category,
          zone: draft.zone.trim(),
          location: draft.location.trim(),
          place: draft.place,
          reporterName: 'Dony Mansour',
          reportedAt: DateTime(2026, 11, 6, 14),
          reference: 'LF-412',
        ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ThemeData _theme(Brightness brightness) => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: brightness)
          .copyWith(secondary: AppColors.secondary, onSecondary: AppColors.onSecondary),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      ),
    );

/// A page with a button opening the sheet; [results] gets what it resolves to.
Future<List<LostItem?>> _pumpAndOpen(
  WidgetTester tester,
  _FakeForumRepository repo, {
  Brightness brightness = Brightness.light,
  double textScale = 1,
  Size size = const Size(400, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final results = <LostItem?>[];

  await tester.pumpWidget(
    ProviderScope(
      overrides: [forumRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: _theme(brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async => results.add(await showPublishLostItemSheet(context)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

/// The text field under the label [label].
Finder _field(String label) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
      matching: find.byType(TextField),
    );

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _publish(WidgetTester tester) async {
  await _tap(tester, find.text("Publier l'annonce"));
  await tester.pumpAndSettle();
}

Future<void> _fillCommon(WidgetTester tester) async {
  await tester.enterText(_field('Objet'), 'Clés Peugeot');
  await _tap(tester, find.text('Clés'));
  await tester.enterText(_field('Zone'), 'Parking');
  await tester.enterText(_field('Lieu précis'), 'Parking Amphi A (Ghazela)');
  await _tap(tester, find.text('Parking').last);
}

void main() {
  testWidgets('the Perdu / Trouvé toggle switches the kind fields', (tester) async {
    await _pumpAndOpen(tester, _FakeForumRepository());

    expect(find.text('Publier une annonce'), findsOneWidget);
    expect(find.text('Récompense (optionnel)'), findsOneWidget);
    expect(find.text('Détail distinctif (optionnel)'), findsOneWidget);
    expect(find.text('Urgent'), findsOneWidget);
    expect(find.text("Où récupérer l'objet ?"), findsNothing);

    await _tap(tester, find.text('Trouvé'));

    expect(find.text("Où récupérer l'objet ?"), findsOneWidget);
    expect(find.text('Accueil Bloc C (Ghazela)'), findsOneWidget);
    expect(find.text('Récompense (optionnel)'), findsNothing);
    expect(find.text('Urgent'), findsNothing);
    expect(find.textContaining('Gardez un détail secret'), findsOneWidget);
  });

  testWidgets('shows the French messages of the API and sends nothing', (tester) async {
    final repo = _FakeForumRepository();
    await _pumpAndOpen(tester, repo);

    await _publish(tester);

    expect(find.text("Donnez un titre à l'annonce (ex : Calculatrice TI-84)."), findsOneWidget);
    expect(find.text("Choisissez une catégorie d'objet."), findsOneWidget);
    expect(find.text('Indiquez la zone (ex : Bloc C).'), findsOneWidget);
    expect(find.text('Précisez le lieu (ex : Salle C12).'), findsOneWidget);
    expect(find.text('Choisissez le type de lieu.'), findsOneWidget);
    expect(repo.drafts, isEmpty);

    await _tap(tester, find.text('Trouvé'));
    await _publish(tester);
    expect(find.text("Indiquez où l'objet a été déposé (ex : Accueil Bloc C)."), findsOneWidget);
    expect(repo.drafts, isEmpty);
  });

  testWidgets('publishes a lost item with its reward and urgency', (tester) async {
    final repo = _FakeForumRepository();
    final results = await _pumpAndOpen(tester, repo);

    await _fillCommon(tester);
    await tester.enterText(_field('Détail distinctif (optionnel)'), 'Boîtier 3 boutons noir');
    await tester.enterText(_field('Récompense (optionnel)'), 'Café offert ☕');
    await _tap(tester, find.text('Urgent'));
    await _publish(tester);

    final draft = repo.drafts.single;
    expect(draft.kind, LostItemKind.lost);
    expect(draft.title, 'Clés Peugeot');
    expect(draft.category, LostItemCategory.keys);
    expect(draft.zone, 'Parking');
    expect(draft.location, 'Parking Amphi A (Ghazela)');
    expect(draft.place, LostItemPlace.parking);
    expect(draft.distinctiveDetail, 'Boîtier 3 boutons noir');
    expect(draft.reward, 'Café offert ☕');
    expect(draft.isUrgent, isTrue);
    expect(draft.pickupDesk, isNull);

    expect(find.text('Publier une annonce'), findsNothing); // closed
    expect(results.single?.id, 'lf-new');
  });

  testWidgets('publishes a found item with a collection point', (tester) async {
    final repo = _FakeForumRepository();
    await _pumpAndOpen(tester, repo);

    // Lost fields typed first are not sent once the item is "Trouvé".
    await tester.enterText(_field('Récompense (optionnel)'), 'Café offert');
    await _tap(tester, find.text('Urgent'));
    await _tap(tester, find.text('Trouvé'));
    await _fillCommon(tester);
    await _tap(tester, find.text('Hall Central (Charguia)'));
    await _publish(tester);

    final draft = repo.drafts.single;
    expect(draft.kind, LostItemKind.found);
    expect(draft.pickupDesk, 'Hall Central (Charguia)');
    expect(draft.reward, isNull);
    expect(draft.isUrgent, isFalse);
    expect(draft.distinctiveDetail, isNull);
  });

  testWidgets("keeps the form open with the API's message", (tester) async {
    final repo = _FakeForumRepository()
      ..reply = const Err(ValidationFailure('Le titre ne doit pas dépasser 80 caractères.'));
    final results = await _pumpAndOpen(tester, repo);

    await _fillCommon(tester);
    await _publish(tester);

    expect(find.text('Le titre ne doit pas dépasser 80 caractères.'), findsOneWidget);
    expect(find.text('Publier une annonce'), findsOneWidget);
    expect(results, isEmpty);

    await _tap(tester, find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(results, [null]);
  });

  for (final brightness in Brightness.values) {
    testWidgets('fits 360 dp at 1.3x text without overflow ($brightness)', (tester) async {
      await _pumpAndOpen(
        tester,
        _FakeForumRepository(),
        brightness: brightness,
        textScale: 1.3,
        size: const Size(360, 3200),
      );
      await _publish(tester); // with every error shown
      expect(tester.takeException(), isNull);

      await _tap(tester, find.text('Trouvé'));
      await _publish(tester);
      expect(find.text('Hall Central (Charguia)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
