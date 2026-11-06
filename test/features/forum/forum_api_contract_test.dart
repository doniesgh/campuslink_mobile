import 'dart:convert';

import 'package:campuspulse/features/forum/data/models/forum_models.dart';
import 'package:campuspulse/features/forum/data/repositories/mock_forum_repository.dart';
import 'package:campuspulse/features/forum/domain/entities/forum_post.dart';
import 'package:campuspulse/features/forum/domain/entities/lost_item.dart';
import 'package:campuspulse/features/forum/domain/entities/lost_item_draft.dart';
import 'package:campuspulse/features/forum/presentation/utils/lost_found_formatters.dart';
import 'package:flutter_test/flutter_test.dart';

import 'forum_api_fixtures.dart';

List<Map<String, dynamic>> _decode(String body) =>
    (jsonDecode(body) as List<dynamic>).cast<Map<String, dynamic>>();

Map<String, dynamic> _decodeObject(String body) => jsonDecode(body) as Map<String, dynamic>;

/// Every field but the date (the mock's dates are relative to the real "now").
Map<String, Object?> _postFields(ForumPost p) => {
      'id': p.id,
      'authorName': p.authorName,
      'authorInfo': p.authorInfo,
      'category': p.category,
      'tag': p.tag,
      'body': p.body,
      'place': p.place,
      'upvotes': p.upvotes,
      'comments': p.comments,
      'status': p.status,
      'isUpvotedByMe': p.isUpvotedByMe,
    };

/// Every field but the id and the date (both set by whoever stores the post).
Map<String, Object?> _publishedPostFields(ForumPost p) => _postFields(p)..remove('id');


Map<String, Object?> _itemFields(LostItem i) => {
      'id': i.id,
      'kind': i.kind,
      'title': i.title,
      'category': i.category,
      'zone': i.zone,
      'location': i.location,
      'place': i.place,
      'reporterName': i.reporterName,
      'reporterIsStaff': i.reporterIsStaff,
      'reference': i.reference,
      'photoCount': i.photoCount,
      'isUrgent': i.isUrgent,
      'reward': i.reward,
      'distinctiveDetail': i.distinctiveDetail,
      'dropOffNote': i.dropOffNote,
      'pickupDesk': i.pickupDesk,
      'isSerialHidden': i.isSerialHidden,
      'action': i.action,
    };

Map<String, Object?> _publishedItemFields(LostItem i) => _itemFields(i)..remove('id');

/// The drafts the fixtures were published with.
const _lostDraft = LostItemDraft(
  kind: LostItemKind.lost,
  title: 'AirPods Pro (boîtier blanc)',
  category: LostItemCategory.audio,
  zone: 'Bloc E',
  location: 'Salle E204 (Charguia)',
  place: LostItemPlace.classroom,
  distinctiveDetail: 'Gravure « D.M. » sur le boîtier',
  reward: 'Café offert ☕',
  isUrgent: true,
);

const _foundDraft = LostItemDraft(
  kind: LostItemKind.found,
  title: 'Parapluie noir',
  category: LostItemCategory.other,
  zone: 'Bibliothèque',
  location: 'Bibliothèque centrale (Étage 1)',
  place: LostItemPlace.library,
  pickupDesk: 'Accueil Bloc C',
);

const _ideaBody = 'Un distributeur de boissons chaudes au Bloc E pour les cours du soir ?';

void main() {
  final mock = MockForumRepository();

  group('GET /forum/highlights response', () {
    final posts = [for (final json in _decode(highlightsResponse)) ForumPostModel.fromJson(json)];

    test('parses into the same posts as the mock, newest first', () async {
      final expected = (await mock.getHighlights()).unwrap();
      expect([for (final p in posts) _postFields(p)], [for (final p in expected) _postFields(p)]);
    });

    test('dates are UTC instants converted to local time', () {
      expect([for (final p in posts) p.postedAt.toUtc()], [
        DateTime.utc(2026, 11, 6, 12, 48),
        DateTime.utc(2026, 11, 6, 12, 15),
        DateTime.utc(2026, 11, 6, 11),
      ]);
      expect(posts.every((p) => !p.postedAt.isUtc), isTrue);
    });
  });

  group('GET /forum/lost-items response', () {
    final items = [for (final json in _decode(lostItemsResponse)) LostItemModel.fromJson(json)];

    test('parses into the same items as the mock', () async {
      final expected = (await mock.getLostItems()).unwrap();
      final byId = {for (final i in items) i.id: _itemFields(i)};
      expect(byId.keys.toSet(), {for (final i in expected) i.id});
      for (final item in expected) {
        expect(byId[item.id], _itemFields(item), reason: item.id);
      }
    });

    test('is newest first, with the seed-time relative dates', () {
      expect([for (final i in items) (i.id, i.reportedAt.toUtc())], [
        ('lf-409', DateTime.utc(2026, 11, 6, 12, 15)),
        ('lf-411', DateTime.utc(2026, 11, 6, 10)),
        ('lf-406', DateTime.utc(2026, 11, 5, 15, 30)),
        ('lf-404', DateTime.utc(2026, 11, 5, 8, 45)),
        ('lf-402', DateTime.utc(2026, 11, 4, 12)),
        ('lf-398', DateTime.utc(2026, 11, 3, 16)),
      ]);
      final seededAt = DateTime.utc(2026, 11, 6, 13).toLocal();
      expect(formatLostItemTime(items.first.reportedAt, now: seededAt), 'Il y a 45 min');
    });

    test('keeps every action of the board', () {
      expect({for (final i in items) i.action}, LostItemAction.values.toSet());
    });
  });

  group('POST /forum/lost-items response', () {
    final lost = LostItemModel.fromJson(_decodeObject(publishedLostItemResponse));
    final found = LostItemModel.fromJson(_decodeObject(publishedFoundItemResponse));

    test('parses into the published items, with the server-set fields', () {
      expect(lost.reporterName, 'Dony Mansour');
      expect(lost.reporterIsStaff, isFalse);
      expect(lost.reference, 'LF-412');
      expect(lost.photoCount, 0);
      expect(lost.isUrgent, isTrue);
      expect(lost.reward, 'Café offert ☕');
      expect(lost.action, LostItemAction.reportFound);
      expect(lost.reportedAt.isUtc, isFalse);

      expect(found.reference, 'LF-413');
      expect(found.pickupDesk, 'Accueil Bloc C');
      expect(found.dropOffNote, isNull);
      expect(found.action, LostItemAction.claim);
    });

    test('the draft body sends what the API stored', () {
      final sent = _lostDraft.toJson();
      for (final key in sent.keys) {
        expect(_decodeObject(publishedLostItemResponse)[key], sent[key], reason: key);
      }
      final sentFound = _foundDraft.toJson();
      for (final key in sentFound.keys) {
        expect(_decodeObject(publishedFoundItemResponse)[key], sentFound[key], reason: key);
      }
    });

    test('the mock publishes the same items (but the id and date)', () async {
      final repo = MockForumRepository();
      final mockLost = (await repo.publishLostItem(_lostDraft)).unwrap();
      final mockFound = (await repo.publishLostItem(_foundDraft)).unwrap();
      expect(_publishedItemFields(mockLost), _publishedItemFields(lost));
      expect(_publishedItemFields(mockFound), _publishedItemFields(found));
    });

    test('the board then lists them first, newest first', () {
      final board = [
        for (final json in _decode(lostItemsAfterPublishingResponse)) LostItemModel.fromJson(json),
      ];
      expect([for (final i in board) i.id], [found.id, lost.id]);
    });
  });

  group('POST /forum/ideas response', () {
    final idea = ForumPostModel.fromJson(_decodeObject(publishedIdeaResponse));

    test('parses into the published idea', () {
      expect(idea.category, PostCategory.idea);
      expect(idea.authorName, 'Dony Mansour');
      expect(idea.authorInfo, '4BI - Software Eng.');
      expect(idea.tag, 'Vie de campus');
      expect(idea.body, _ideaBody);
      expect(idea.upvotes, 0);
      expect(idea.comments, 0);
      expect(idea.status, isNull);
      expect(idea.isUpvotedByMe, isFalse);
      expect(idea.postedAt.isUtc, isFalse);
    });

    test('the mock publishes the same idea (but the id and date)', () async {
      final mockIdea =
          (await MockForumRepository().publishIdea(body: _ideaBody, tag: 'Vie de campus'))
              .unwrap();
      expect(_publishedPostFields(mockIdea), _publishedPostFields(idea));
    });
  });

  group('POST /forum/ideas/:id/upvote response', () {
    test('parses into the new count and state, like the mock', () async {
      final upvote = ideaUpvoteFromJson(_decodeObject(ideaUpvoteResponse));
      expect(upvote, (upvotes: 43, isUpvotedByMe: true));
      expect((await MockForumRepository().toggleIdeaUpvote('post-3')).unwrap(), upvote);
    });
  });

  group('GET /forum/ideas response', () {
    final ideas = [for (final json in _decode(ideasResponse)) ForumPostModel.fromJson(json)];

    test('is most upvoted first, with the student vote', () {
      expect([for (final i in ideas) (i.id, i.upvotes, i.isUpvotedByMe)], [
        ('post-3', 43, true),
        (ideas.last.id, 0, false),
      ]);
      expect(ideas.every((i) => i.category == PostCategory.idea), isTrue);
    });

    test('the mock lists the same ideas after the same actions', () async {
      final repo = MockForumRepository();
      await repo.publishIdea(body: _ideaBody, tag: 'Vie de campus');
      await repo.toggleIdeaUpvote('post-3');
      final expected = (await repo.getIdeas()).unwrap();
      expect(
        [for (final i in expected) _publishedPostFields(i)],
        [for (final i in ideas) _publishedPostFields(i)],
      );
    });

    test('the highlights carry the same vote for Home', () {
      final highlights = [
        for (final json in _decode(highlightsAfterVotingResponse)) ForumPostModel.fromJson(json),
      ];
      final idea = highlights.singleWhere((p) => p.id == 'post-3');
      expect(idea.upvote, (upvotes: 43, isUpvotedByMe: true));
      expect(highlights.where((p) => p.isUpvotedByMe), [idea]);
      expect(highlights.first.id, ideas.last.id); // the new idea is the latest post
    });
  });

  group('fromJson', () {
    final post = _decode(highlightsResponse).first;
    final item = _decode(lostItemsResponse).first;

    test('missing optional fields fall back to the entity defaults', () {
      final minimal = LostItemModel.fromJson({
        for (final key in ['id', 'kind', 'title', 'category', 'zone', 'location', 'place',
            'reporterName', 'reportedAt'])
          key: item[key],
      });
      expect(minimal.reference, isNull);
      expect(minimal.photoCount, 0);
      expect(minimal.reporterIsStaff, isFalse);
      expect(minimal.isSerialHidden, isFalse);

      final minimalPost = ForumPostModel.fromJson({...post}
        ..remove('upvotes')
        ..remove('comments')
        ..remove('place')
        ..remove('status'));
      expect(minimalPost.upvotes, 0);
      expect(minimalPost.place, isNull);

      final beforeVotes = ForumPostModel.fromJson({...post}..remove('isUpvotedByMe'));
      expect(beforeVotes.isUpvotedByMe, isFalse);
    });

    test('an unknown item category or place shows as "other"', () {
      final parsed = LostItemModel.fromJson({...item, 'category': 'laptop', 'place': 'gym'});
      expect(parsed.category, LostItemCategory.other);
      expect(parsed.place, LostItemPlace.other);
    });

    test('an unknown post category or item kind is a format error', () {
      expect(
        () => ForumPostModel.fromJson({...post, 'category': 'event'}),
        throwsFormatException,
      );
      expect(() => LostItemModel.fromJson({...item, 'kind': 'stolen'}), throwsFormatException);
    });
  });
}
