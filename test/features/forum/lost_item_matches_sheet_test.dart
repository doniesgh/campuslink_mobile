import 'package:campuspulse/core/error/failures.dart';
import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/core/providers/clock_provider.dart';
import 'package:campuspulse/features/forum/domain/entities/lost_item.dart';
import 'package:campuspulse/features/forum/domain/entities/lost_item_match.dart';
import 'package:campuspulse/features/forum/domain/repositories/forum_repository.dart';
import 'package:campuspulse/features/forum/presentation/providers/forum_providers.dart';
import 'package:campuspulse/features/forum/presentation/widgets/lost_item_matches_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers the matches with [reply] (changeable between calls).
class _FakeForumRepository implements ForumRepository {
  _FakeForumRepository(this.reply);

  Result<LostItemMatches> reply;
  final calls = <String>[];

  @override
  Future<Result<LostItemMatches>> getLostItemMatches(String id) async {
    calls.add(id);
    return reply;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

final _now = DateTime(2026, 11, 6, 14);

LostItem _item(String id, String title, {LostItemKind kind = LostItemKind.found}) => LostItem(
      id: id,
      kind: kind,
      title: title,
      category: LostItemCategory.calculator,
      zone: 'Bloc C',
      location: 'Salle C12 (Ghazela)',
      place: LostItemPlace.classroom,
      reporterName: 'Youssef M.',
      reportedAt: _now.subtract(const Duration(minutes: 45)),
      pickupDesk: 'Accueil Bloc C',
    );

final _source = _item('lf-407', 'Calculatrice graphique TI-84', kind: LostItemKind.lost);
final _calculator = _item('lf-409', 'Calculatrice TI-84 Plus CE');
final _casio = _item('lf-500', 'Calculatrice Casio');

LostItemMatches _withAi() => LostItemMatches(
      ai: true,
      model: 'test/model',
      items: [
        LostItemMatch(
          item: _calculator,
          score: 90,
          reason: 'Même modèle TI-84, trouvée au Bloc C.',
          reasons: const ['Même catégorie', 'Même jour'],
          ai: true,
        ),
        LostItemMatch(
          item: _casio,
          score: 62,
          reason: 'Même catégorie · Lieu proche',
          reasons: const ['Même catégorie', 'Lieu proche'],
        ),
      ],
    );

/// A page with a button opening the sheet for [_source]; [onPicked] gets its result.
Future<_FakeForumRepository> _pump(
  WidgetTester tester,
  Result<LostItemMatches> reply, {
  void Function(LostItem?)? onPicked,
}) async {
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = _FakeForumRepository(reply);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        forumRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWith((ref) => Stream.value(_now)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final picked = await showLostItemMatchesSheet(context, _source);
                onPicked?.call(picked);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('lists the matches with score, place, date and reason, and the IA chip',
      (tester) async {
    final repo = await _pump(tester, Success(_withAi()));

    expect(repo.calls, ['lf-407']);
    expect(find.text('Correspondances possibles'), findsOneWidget);
    expect(find.text('Objets trouvés qui ressemblent à cette annonce.'), findsOneWidget);
    expect(find.text('IA'), findsOneWidget);

    expect(find.text('Calculatrice TI-84 Plus CE'), findsOneWidget);
    expect(find.text('90 %'), findsOneWidget);
    expect(find.text('TROUVÉ · BLOC C · IL Y A 45 MIN'), findsNWidgets(2));
    expect(find.text('Salle C12 (Ghazela)'), findsNWidgets(2));
    expect(find.text('IA : Même modèle TI-84, trouvée au Bloc C.', findRichText: true), findsOneWidget);

    expect(find.text('Calculatrice Casio'), findsOneWidget);
    expect(find.text('62 %'), findsOneWidget);
    expect(find.text('Même catégorie · Lieu proche', findRichText: true), findsOneWidget);
  });

  testWidgets('without AI there is no IA chip', (tester) async {
    await _pump(
      tester,
      Success(LostItemMatches(items: [_withAi().items.last])),
    );

    expect(find.text('Calculatrice Casio'), findsOneWidget);
    expect(find.text('IA'), findsNothing);
  });

  testWidgets('tapping a match closes the sheet with that item', (tester) async {
    LostItem? picked;
    await _pump(tester, Success(_withAi()), onPicked: (item) => picked = item);

    await tester.tap(find.text('Calculatrice Casio'));
    await tester.pumpAndSettle();

    expect(find.text('Correspondances possibles'), findsNothing);
    expect(picked?.id, 'lf-500');
  });

  testWidgets('shows an empty state', (tester) async {
    await _pump(tester, const Success(LostItemMatches(items: [])));

    expect(find.text('Aucune correspondance pour le moment'), findsOneWidget);
    expect(find.text('Réessayer'), findsNothing);
  });

  testWidgets('shows the error, and retries', (tester) async {
    final repo = await _pump(tester, const Err(NetworkFailure()));

    expect(find.text('Impossible de charger les correspondances'), findsOneWidget);
    expect(find.text('No internet connection.'), findsOneWidget);

    repo.reply = Success(_withAi());
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(repo.calls, ['lf-407', 'lf-407']);
    expect(find.text('Calculatrice TI-84 Plus CE'), findsOneWidget);
  });
}
