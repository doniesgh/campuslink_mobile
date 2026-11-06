import 'dart:convert';
import 'dart:typed_data';

import 'package:campuspulse/core/error/failures.dart';
import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/features/notifications/data/repositories/mock_notification_repository.dart';
import 'package:campuspulse/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:campuspulse/features/notifications/domain/entities/app_notification.dart';
import 'package:campuspulse/features/notifications/presentation/providers/notification_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'notifications_api_fixture.dart';

typedef _Reply = ({int status, String body});

/// Answers like the backend: the seeded feed, 204 for the read calls, and
/// 404 for ids the student doesn't have. Records every request.
class _FakeApi implements HttpClientAdapter {
  final requests = <String>[];
  final knownIds = {
    for (final n in jsonDecode(seededNotificationsJson) as List<dynamic>)
      (n as Map<String, dynamic>)['id'] as String,
  };

  /// Overrides the answer to every request when set.
  _Reply? forced;

  _Reply _route(RequestOptions o) {
    final path = o.uri.path;
    if (o.method == 'GET' && path == '/api/notifications') {
      return (status: 200, body: seededNotificationsJson);
    }
    if (o.method == 'POST' && path == '/api/notifications/read-all') {
      return (status: 204, body: '');
    }
    final read = RegExp(r'^/api/notifications/([^/]+)/read$').firstMatch(path);
    if (o.method == 'POST' && read != null) {
      return knownIds.contains(Uri.decodeComponent(read[1]!))
          ? (status: 204, body: '')
          : (status: 404, body: '{"message":"Notification not found."}');
    }
    return (status: 404, body: '{"message":"Route not found."}');
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add('${options.method} ${options.uri.path}');
    final reply = forced ?? _route(options);
    return ResponseBody.fromString(
      reply.body,
      reply.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

({NotificationRepositoryImpl repo, _FakeApi api}) _setUp() {
  final api = _FakeApi();
  final dio = Dio(BaseOptions(baseUrl: 'http://campus.test/api'))..httpClientAdapter = api;
  return (repo: NotificationRepositoryImpl(dio), api: api);
}

void main() {
  group('NotificationRepositoryImpl', () {
    test('getNotifications parses the feed', () async {
      final (:repo, :api) = _setUp();

      final items = (await repo.getNotifications()).dataOrNull!;

      expect(api.requests, ['GET /api/notifications']);
      expect(items, hasLength(9));
      expect(items.first.id, 'room-change-gl');
      expect(items.first.attachment, isA<PlaceAttachment>());
      expect(items[1].link?.destination, NotificationDestination.ride);
      expect(items[1].link?.id, 'es-4091');
    });

    test('markAsRead posts to the notification and accepts the 204', () async {
      final (:repo, :api) = _setUp();

      final result = await repo.markAsRead('room-change-gl');

      expect(result, isA<Success<void>>());
      expect(api.requests, ['POST /api/notifications/room-change-gl/read']);
    });

    test('markAsRead of an unknown notification fails with the API message', () async {
      final repo = _setUp().repo;

      final result = await repo.markAsRead('nope');

      final failure = (result as Err<void>).failure;
      expect(failure, isA<ServerFailure>());
      expect(failure.message, 'Notification not found.');
    });

    test('markAllAsRead posts to read-all', () async {
      final (:repo, :api) = _setUp();

      expect(await repo.markAllAsRead(), isA<Success<void>>());
      expect(api.requests, ['POST /api/notifications/read-all']);
    });

    test('errors become failures, never exceptions', () async {
      final (:repo, :api) = _setUp();
      api.forced = (status: 401, body: '{"message":"Invalid credentials or expired session."}');
      expect((await repo.getNotifications() as Err).failure, isA<UnauthorizedFailure>());

      api.forced = (status: 500, body: '{"message":"Something went wrong. Please try again."}');
      expect((await repo.markAllAsRead() as Err).failure, isA<ServerFailure>());

      api.forced = (status: 200, body: '{"not":"a list"}');
      expect((await repo.getNotifications() as Err).failure, isA<UnknownFailure>());
    });
  });

  group('NotificationsController with the API', () {
    ProviderContainer container(NotificationRepositoryImpl repo) {
      final c = ProviderContainer(
        overrides: [notificationRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('markAsRead updates the count at once and keeps it on success', () async {
      final (:repo, :api) = _setUp();
      final c = container(repo);
      await c.read(notificationsControllerProvider.future);
      expect(c.read(unreadNotificationCountProvider), 3);

      final pending = c.read(notificationsControllerProvider.notifier).markAsRead('room-change-gl');
      expect(c.read(unreadNotificationCountProvider), 2); // optimistic

      expect(await pending, isNull);
      expect(c.read(unreadNotificationCountProvider), 2);
      expect(api.requests.last, 'POST /api/notifications/room-change-gl/read');
    });

    test('a 404 on markAsRead puts the notification back to unread', () async {
      final (:repo, :api) = _setUp();
      final c = container(repo);
      await c.read(notificationsControllerProvider.future);
      api.knownIds.remove('room-change-gl'); // deleted on the server meanwhile

      final pending = c.read(notificationsControllerProvider.notifier).markAsRead('room-change-gl');
      expect(c.read(unreadNotificationCountProvider), 2); // optimistic

      final failure = await pending;
      expect(failure?.message, 'Notification not found.');
      expect(c.read(unreadNotificationCountProvider), 3);
    });

    test('markAllAsRead clears the count, and a failure restores it', () async {
      final (:repo, :api) = _setUp();
      final c = container(repo);
      await c.read(notificationsControllerProvider.future);
      final notifier = c.read(notificationsControllerProvider.notifier);

      api.forced = (status: 503, body: '{"message":"Try again later."}');
      expect((await notifier.markAllAsRead())?.message, 'Try again later.');
      expect(c.read(unreadNotificationCountProvider), 3);

      api.forced = null;
      expect(await notifier.markAllAsRead(), isNull);
      expect(c.read(unreadNotificationCountProvider), 0);
      expect(api.requests.last, 'POST /api/notifications/read-all');
    });
  });

  test('USE_MOCK=true (the test default) keeps the in-memory repository', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(notificationRepositoryProvider), isA<MockNotificationRepository>());
  });
}
