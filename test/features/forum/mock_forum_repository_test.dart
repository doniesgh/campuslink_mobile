import 'package:campuspulse/core/error/failures.dart';
import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/features/forum/data/repositories/mock_forum_repository.dart';
import 'package:campuspulse/features/forum/domain/entities/lost_item.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
