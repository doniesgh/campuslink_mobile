import 'dart:convert';
import 'dart:typed_data';

import 'package:campuspulse/core/error/failures.dart';
import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/features/forum/data/repositories/forum_repository_impl.dart';
import 'package:campuspulse/features/forum/data/repositories/mock_forum_repository.dart';
import 'package:campuspulse/features/forum/domain/entities/forum_post.dart';
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

  test('the provider keeps the mock while USE_MOCK is true (the default)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(forumRepositoryProvider), isA<MockForumRepository>());
  });
}
