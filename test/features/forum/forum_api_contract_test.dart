import 'dart:convert';

import 'package:campuspulse/features/forum/data/models/forum_models.dart';
import 'package:campuspulse/features/forum/data/repositories/mock_forum_repository.dart';
import 'package:campuspulse/features/forum/domain/entities/forum_post.dart';
import 'package:campuspulse/features/forum/domain/entities/lost_item.dart';
import 'package:campuspulse/features/forum/presentation/utils/lost_found_formatters.dart';
import 'package:flutter_test/flutter_test.dart';

import 'forum_api_fixtures.dart';

List<Map<String, dynamic>> _decode(String body) =>
    (jsonDecode(body) as List<dynamic>).cast<Map<String, dynamic>>();

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
    };

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
