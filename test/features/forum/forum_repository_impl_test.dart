import 'dart:convert';
import 'dart:typed_data';

import 'package:campuspulse/core/error/failures.dart';
import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/features/forum/data/repositories/forum_repository_impl.dart';
import 'package:campuspulse/features/forum/data/repositories/mock_forum_repository.dart';
import 'package:campuspulse/features/forum/domain/entities/forum_post.dart';
import 'package:campuspulse/features/forum/domain/entities/lost_item.dart';
import 'package:campuspulse/features/forum/domain/entities/lost_item_draft.dart';
import 'package:campuspulse/features/forum/presentation/providers/forum_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'forum_api_fixtures.dart';

/// Answers every request with [status] and [body], and records the requests.
class _FakeApi implements HttpClientAdapter {
  int status = 200;
  String body = '[]';
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _FakeApi api;
  late ForumRepositoryImpl repo;

  setUp(() {
    api = _FakeApi();
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api'))..httpClientAdapter = api;
    repo = ForumRepositoryImpl(dio);
  });

  Failure failureOf(Result<Object?> result) => (result as Err<Object?>).failure;

  test('getHighlights reads GET /forum/highlights', () async {
    api.body = highlightsResponse;

    final posts = (await repo.getHighlights()).unwrap();

    expect(api.requests.single.method, 'GET');
    expect(api.requests.single.uri.toString(), 'http://api.test/api/forum/highlights');
    expect([for (final p in posts) p.id], ['post-1', 'post-2', 'post-3']);
    expect(posts.last.category, PostCategory.idea);
  });

  test('getLostItems reads GET /forum/lost-items', () async {
    api.body = lostItemsResponse;

    final items = (await repo.getLostItems()).unwrap();

    expect(api.requests.single.uri.toString(), 'http://api.test/api/forum/lost-items');
    expect(items, hasLength(6));
    expect(items.first.id, 'lf-409');
  });

  test('an unexpected body is a failure, not a crash', () async {
    api.body = '{"message":"not a list"}';
    expect(failureOf(await repo.getLostItems()), isA<UnknownFailure>());
  });

  group('sendLostItemRequest', () {
    test('posts the proof to the item', () async {
      api
        ..status = 201
        ..body = '{"id":"r1","itemId":"lf-409","proof":"Autocollant",'
            '"createdAt":"2026-11-06T13:00:00.000Z"}';

      final result = await repo.sendLostItemRequest(itemId: 'lf-409', proof: 'Autocollant');

      expect(result, isA<Success<void>>());
      final sent = api.requests.single;
      expect(sent.method, 'POST');
      expect(sent.uri.toString(), 'http://api.test/api/forum/lost-items/lf-409/requests');
      expect(sent.data, {'proof': 'Autocollant'});
    });

    test('encodes the item id in the path', () async {
      api.status = 201;
      await repo.sendLostItemRequest(itemId: 'a/b', proof: 'x');
      expect(api.requests.single.uri.path, '/api/forum/lost-items/a%2Fb/requests');
    });

    Future<Failure> failing(int status, String message) async {
      api
        ..status = status
        ..body = jsonEncode({'message': message});
      return failureOf(await repo.sendLostItemRequest(itemId: 'lf-409', proof: ' '));
    }

    test('a 422 is a validation failure with the API message', () async {
      final failure = await failing(422, 'Please add a detail that identifies the item.');
      expect(failure, isA<ValidationFailure>());
      expect(failure.message, 'Please add a detail that identifies the item.');
    });

    test('a 404 or 409 is shown with the API message', () async {
      final gone = await failing(404, 'This item is no longer listed.');
      expect(gone, isA<ServerFailure>());
      expect(gone.message, 'This item is no longer listed.');

      final twice = await failing(409, 'You already sent a request for this item.');
      expect(twice, isA<ServerFailure>());
      expect(twice.message, 'You already sent a request for this item.');
    });
  });

  group('publishLostItem', () {
    const lost = LostItemDraft(
      kind: LostItemKind.lost,
      title: '  AirPods Pro ',
      category: LostItemCategory.audio,
      zone: 'Bloc E',
      location: 'Salle E204',
      place: LostItemPlace.classroom,
      distinctiveDetail: '  ',
      reward: 'Café offert ☕',
      isUrgent: true,
      // Not a lost item's field: never sent.
      pickupDesk: 'Accueil Bloc C',
    );

    test('posts the lost fields to POST /forum/lost-items and reads the item', () async {
      api
        ..status = 201
        ..body = publishedLostItemResponse;

      final item = (await repo.publishLostItem(lost)).unwrap();

      final sent = api.requests.single;
      expect(sent.method, 'POST');
      expect(sent.uri.toString(), 'http://api.test/api/forum/lost-items');
      expect(sent.data, {
        'kind': 'lost',
        'title': 'AirPods Pro',
        'category': 'audio',
        'zone': 'Bloc E',
        'location': 'Salle E204',
        'place': 'classroom',
        'reward': 'Café offert ☕',
        'isUrgent': true,
      });
      expect(item.reference, 'LF-412');
      expect(item.reporterName, 'Dony Mansour');
    });

    test('sends the drop-off fields of a found item only', () async {
      api
        ..status = 201
        ..body = publishedFoundItemResponse;

      await repo.publishLostItem(const LostItemDraft(
        kind: LostItemKind.found,
        title: 'Parapluie noir',
        category: LostItemCategory.other,
        zone: 'Bibliothèque',
        location: 'Bibliothèque centrale',
        place: LostItemPlace.library,
        reward: 'ignored',
        isUrgent: true,
        dropOffNote: ' ',
        pickupDesk: 'Accueil Bloc C',
      ));

      expect(api.requests.single.data, {
        'kind': 'found',
        'title': 'Parapluie noir',
        'category': 'other',
        'zone': 'Bibliothèque',
        'location': 'Bibliothèque centrale',
        'place': 'library',
        'pickupDesk': 'Accueil Bloc C',
      });
    });

    test('a 422 is a validation failure with the French message', () async {
      api
        ..status = 422
        ..body = jsonEncode({'message': 'Indiquez la zone (ex : Bloc C).'});
      final failure = failureOf(await repo.publishLostItem(lost));
      expect(failure, isA<ValidationFailure>());
      expect(failure.message, 'Indiquez la zone (ex : Bloc C).');
    });
  });

  group('ideas', () {
    test('getIdeas reads GET /forum/ideas', () async {
      api.body = ideasResponse;

      final ideas = (await repo.getIdeas()).unwrap();

      expect(api.requests.single.method, 'GET');
      expect(api.requests.single.uri.toString(), 'http://api.test/api/forum/ideas');
      expect(ideas.first.id, 'post-3');
      expect(ideas.first.upvote, (upvotes: 43, isUpvotedByMe: true));
    });

    test('publishIdea posts the trimmed text and theme', () async {
      api
        ..status = 201
        ..body = publishedIdeaResponse;

      final idea =
          (await repo.publishIdea(body: '  Un distributeur au Bloc E ? ', tag: ' Vie de campus '))
              .unwrap();

      final sent = api.requests.single;
      expect(sent.method, 'POST');
      expect(sent.uri.toString(), 'http://api.test/api/forum/ideas');
      expect(sent.data, {'body': 'Un distributeur au Bloc E ?', 'tag': 'Vie de campus'});
      expect(idea.authorInfo, '4BI - Software Eng.');
    });

    test('publishIdea leaves a blank theme out', () async {
      api
        ..status = 201
        ..body = publishedIdeaResponse;
      await repo.publishIdea(body: 'Un distributeur au Bloc E ?', tag: '  ');
      expect(api.requests.single.data, {'body': 'Un distributeur au Bloc E ?'});
    });

    test('a refused idea is a validation failure', () async {
      api
        ..status = 422
        ..body = jsonEncode({'message': 'Décrivez votre idée.'});
      final failure = failureOf(await repo.publishIdea(body: ' '));
      expect(failure, isA<ValidationFailure>());
      expect(failure.message, 'Décrivez votre idée.');
    });

    test('toggleIdeaUpvote posts to the encoded idea path and reads the state', () async {
      api.body = ideaUpvoteResponse;

      final upvote = (await repo.toggleIdeaUpvote('post-3')).unwrap();
      await repo.toggleIdeaUpvote('a/b');

      expect(api.requests.first.method, 'POST');
      expect(api.requests.first.uri.toString(), 'http://api.test/api/forum/ideas/post-3/upvote');
      expect(api.requests.last.uri.path, '/api/forum/ideas/a%2Fb/upvote');
      expect(upvote, (upvotes: 43, isUpvotedByMe: true));
    });

    test('an idea that is gone is a server failure with the API message', () async {
      api
        ..status = 404
        ..body = jsonEncode({'message': "Cette idée n'existe plus."});
      final failure = failureOf(await repo.toggleIdeaUpvote('idea-0'));
      expect(failure, isA<ServerFailure>());
      expect(failure.message, "Cette idée n'existe plus.");
    });
  });

  test('the provider keeps the mock while USE_MOCK is true (the default)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(forumRepositoryProvider), isA<MockForumRepository>());
  });
}
