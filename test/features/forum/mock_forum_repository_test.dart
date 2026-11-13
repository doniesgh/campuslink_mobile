import 'package:campuspulse/core/error/failures.dart';
import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/features/forum/data/repositories/mock_forum_repository.dart';
import 'package:campuspulse/features/forum/domain/entities/forum_post.dart';
import 'package:campuspulse/features/forum/domain/entities/lost_item.dart';
import 'package:campuspulse/features/forum/domain/entities/lost_item_draft.dart';
import 'package:flutter_test/flutter_test.dart';

const _keys = LostItemDraft(
  kind: LostItemKind.lost,
  title: 'Clés Peugeot',
  category: LostItemCategory.keys,
  zone: 'Parking',
  location: 'Parking Amphi A',
  place: LostItemPlace.parking,
  reward: 'Café offert ☕',
  isUrgent: true,
);

LostItemDraft _found({String? desk = 'Accueil Bloc C', String title = 'Parapluie noir'}) =>
    LostItemDraft(
      kind: LostItemKind.found,
      title: title,
      category: LostItemCategory.other,
      zone: 'Bibliothèque',
      location: 'Bibliothèque centrale',
      place: LostItemPlace.library,
      pickupDesk: desk,
    );

String _failure(Result<Object?> result) => (result as Err<Object?>).failure.message;

void main() {
  final repo = MockForumRepository();

  test('highlights are unchanged (Home "Campus Highlights")', () async {
    final posts = (await repo.getHighlights()).unwrap();
    expect(posts, hasLength(3));
  });

  test('lost items are newest first and include both kinds', () async {
    final items = (await repo.getLostItems()).unwrap();
    expect(items, isNotEmpty);
    for (var i = 1; i < items.length; i++) {
      expect(items[i - 1].reportedAt.isBefore(items[i].reportedAt), isFalse);
    }
    expect(items.any((i) => i.kind == LostItemKind.lost), isTrue);
    expect(items.any((i) => i.kind == LostItemKind.found), isTrue);
    expect(items.map((i) => i.id).toSet(), hasLength(items.length));
  });

  group('sendLostItemRequest', () {
    test('succeeds with a proof', () async {
      final result = await repo.sendLostItemRequest(itemId: 'lf-409', proof: 'Autocollant');
      expect(result, isA<Success<void>>());
    });

    test('rejects a blank proof', () async {
      final result = await repo.sendLostItemRequest(itemId: 'lf-409', proof: '   ');
      expect((result as Err<void>).failure, isA<ValidationFailure>());
    });

    test('rejects an unknown item', () async {
      final result = await repo.sendLostItemRequest(itemId: 'nope', proof: 'Autocollant');
      expect((result as Err<void>).failure, isA<ServerFailure>());
    });
  });

  group('publishLostItem', () {
    test('publishes first on the board, with the next LF reference', () async {
      final repo = MockForumRepository();
      final keys = (await repo.publishLostItem(_keys)).unwrap();
      final umbrella = (await repo.publishLostItem(_found())).unwrap();

      expect(keys.reference, 'LF-412');
      expect(umbrella.reference, 'LF-413');
      expect(keys.reporterName, 'Dony Mansour');
      expect(keys.isUrgent, isTrue);
      expect(umbrella.pickupDesk, 'Accueil Bloc C');

      final board = (await repo.getLostItems()).unwrap();
      expect([for (final i in board.take(2)) i.id], [umbrella.id, keys.id]);
      expect(board, hasLength(9));
    });

    test('a published item can be claimed', () async {
      final repo = MockForumRepository();
      final umbrella = (await repo.publishLostItem(_found())).unwrap();
      final result = await repo.sendLostItemRequest(itemId: umbrella.id, proof: 'Poignée cassée');
      expect(result, isA<Success<void>>());
    });

    test('refuses a draft like the API, with its French message', () async {
      final repo = MockForumRepository();
      final noDesk = await repo.publishLostItem(_found(desk: '  '));
      expect((noDesk as Err<LostItem>).failure, isA<ValidationFailure>());
      expect(_failure(noDesk), "Indiquez où l'objet a été déposé (ex : Accueil Bloc C).");
      expect(
        _failure(await repo.publishLostItem(_found(title: ' '))),
        "Donnez un titre à l'annonce (ex : Calculatrice TI-84).",
      );
      expect((await repo.getLostItems()).unwrap(), hasLength(7));
    });
  });

  group('ideas', () {
    test('are most upvoted first, then newest', () async {
      final repo = MockForumRepository();
      final idea = (await repo.publishIdea(body: 'Un distributeur au Bloc E ?')).unwrap();

      final ideas = (await repo.getIdeas()).unwrap();
      expect([for (final i in ideas) i.id], ['post-3', idea.id]);
      expect(ideas.every((i) => i.category == PostCategory.idea), isTrue);
    });

    test('a published idea has the student as author and no votes', () async {
      final idea = (await MockForumRepository().publishIdea(body: '  Plus de prises au foyer. '))
          .unwrap();
      expect(idea.authorName, 'Dony Mansour');
      expect(idea.authorInfo, '4BI - Software Eng.');
      expect(idea.tag, 'Proposition');
      expect(idea.body, 'Plus de prises au foyer.');
      expect(idea.upvote, (upvotes: 0, isUpvotedByMe: false));
    });

    test('a published idea is also the latest highlight', () async {
      final repo = MockForumRepository();
      final idea = (await repo.publishIdea(body: 'Un distributeur au Bloc E ?')).unwrap();
      final highlights = (await repo.getHighlights()).unwrap();
      expect(highlights.first.id, idea.id);
      expect(highlights, hasLength(4));
    });

    test('refuses an idea that is too short', () async {
      final result = await MockForumRepository().publishIdea(body: 'Wifi ?');
      expect((result as Err<ForumPost>).failure, isA<ValidationFailure>());
      expect(_failure(result), 'Votre idée est trop courte : 10 caractères minimum.');
    });

    test('the upvote toggles on top of the seeded count, everywhere', () async {
      final repo = MockForumRepository();
      expect((await repo.toggleIdeaUpvote('post-3')).unwrap(), (upvotes: 43, isUpvotedByMe: true));

      final idea = (await repo.getIdeas()).unwrap().first;
      expect(idea.upvote, (upvotes: 43, isUpvotedByMe: true));
      final highlight = (await repo.getHighlights()).unwrap().singleWhere((p) => p.id == 'post-3');
      expect(highlight.upvote, (upvotes: 43, isUpvotedByMe: true));

      expect((await repo.toggleIdeaUpvote('post-3')).unwrap(), (upvotes: 42, isUpvotedByMe: false));
    });

    test('voting for an unknown idea or another post fails', () async {
      final repo = MockForumRepository();
      for (final id in ['nope', 'post-1']) {
        final result = await repo.toggleIdeaUpvote(id);
        expect((result as Err<IdeaUpvote>).failure, isA<ServerFailure>());
        expect(_failure(result), "Cette idée n'existe plus.");
      }
    });
  });

  group('managing a notice', () {
    const notMine =
        "Seul l'auteur de l'annonce (ou un administrateur) peut la modifier ou la supprimer.";

    test("the student's own notices are lf-407 and the ones they publish", () async {
      final repo = MockForumRepository();
      final umbrella = (await repo.publishLostItem(_found())).unwrap();
      final board = (await repo.getLostItems()).unwrap();
      expect([for (final i in board) if (i.canManage) i.id], [umbrella.id, 'lf-407']);
      expect(board.where((i) => i.isMine), hasLength(2));
    });

    test('edits a notice: the form replaces its fields, the rest is kept', () async {
      final repo = MockForumRepository();
      final before = (await repo.getLostItems()).unwrap().singleWhere((i) => i.id == 'lf-407');
      final edited = (await repo.updateLostItem('lf-407', _keys)).unwrap();

      expect(edited.title, 'Clés Peugeot');
      expect(edited.category, LostItemCategory.keys);
      expect(edited.reward, 'Café offert ☕');
      expect(edited.distinctiveDetail, isNull);
      expect(edited.reportedAt, before.reportedAt);
      expect(edited.reporterName, 'Dony Mansour');
      final board = (await repo.getLostItems()).unwrap();
      expect(board.singleWhere((i) => i.id == 'lf-407').title, 'Clés Peugeot');
      expect(board, hasLength(7));
    });

    test("refuses an invalid edit, and anyone else's notice", () async {
      final repo = MockForumRepository();
      final invalid = await repo.updateLostItem('lf-407', _found(desk: ' '));
      expect((invalid as Err<LostItem>).failure, isA<ValidationFailure>());

      for (final result in [
        await repo.updateLostItem('lf-409', _keys),
        await repo.setLostItemStatus('lf-409', LostItemStatus.resolved),
        await repo.deleteLostItem('lf-409'),
      ]) {
        expect(_failure(result), notMine);
      }
      expect(_failure(await repo.deleteLostItem('nope')), "Cette annonce n'existe plus.");
    });

    test('resolves a notice (no more matches), and makes it active again', () async {
      final repo = MockForumRepository();
      final resolved = (await repo.setLostItemStatus('lf-407', LostItemStatus.resolved)).unwrap();
      expect(resolved.isResolved, isTrue);
      expect((await repo.getLostItemMatches('lf-407')).unwrap().items, isEmpty);
      // Nor is it a match of the found calculator any more.
      expect((await repo.getLostItemMatches('lf-409')).unwrap().items, isEmpty);

      await repo.setLostItemStatus('lf-407', LostItemStatus.active);
      final board = (await repo.getLostItems()).unwrap();
      expect(board.singleWhere((i) => i.id == 'lf-407').isResolved, isFalse);
    });

    test('deletes a notice', () async {
      final repo = MockForumRepository();
      expect(await repo.deleteLostItem('lf-407'), isA<Success<void>>());
      final board = (await repo.getLostItems()).unwrap();
      expect(board.map((i) => i.id), isNot(contains('lf-407')));
      expect(board, hasLength(6));
    });

    test('matches by rules, both ways, without AI', () async {
      final repo = MockForumRepository();
      final lost = (await repo.getLostItemMatches('lf-407')).unwrap();
      expect(lost.ai, isFalse);
      expect([for (final m in lost.items) m.item.id], ['lf-409']);
      expect(lost.items.single.score, greaterThanOrEqualTo(80));

      final found = (await repo.getLostItemMatches('lf-409')).unwrap();
      expect([for (final m in found.items) m.item.id], ['lf-407']);
      // Nothing else on the demo board looks alike.
      expect((await repo.getLostItemMatches('lf-406')).unwrap().items, isEmpty);
      expect(_failure(await repo.getLostItemMatches('nope')), "Cette annonce n'existe plus.");
    });
  });
}
