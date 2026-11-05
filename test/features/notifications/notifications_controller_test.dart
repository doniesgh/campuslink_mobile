import 'package:campuspulse/core/error/failures.dart';
import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/features/notifications/data/repositories/mock_notification_repository.dart';
import 'package:campuspulse/features/notifications/domain/entities/app_notification.dart';
import 'package:campuspulse/features/notifications/domain/entities/notification_feed.dart';
import 'package:campuspulse/features/notifications/domain/repositories/notification_repository.dart';
import 'package:campuspulse/features/notifications/presentation/providers/notification_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 5, 10, 30);

MockNotificationRepository _mock() =>
    MockNotificationRepository(clock: () => _now, latency: Duration.zero);

/// Loads fine, but every write fails.
class _ReadOnlyRepository implements NotificationRepository {
  final _inner = _mock();

  @override
  Future<Result<List<AppNotification>>> getNotifications() => _inner.getNotifications();

  @override
  Future<Result<void>> markAsRead(String id) async => const Err(NetworkFailure());

  @override
  Future<Result<void>> markAllAsRead() async => const Err(ServerFailure());
}

ProviderContainer _container(NotificationRepository repo) {
  final container = ProviderContainer(
    overrides: [notificationRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('MockNotificationRepository', () {
    test('seed matches the design: 9 notifications, 3 unread, 2 unread today', () async {
      final items = (await _mock().getNotifications()).dataOrNull!;
      expect(items, hasLength(9));
      expect(unreadCount(items), 3);
      expect(unreadTodayCount(items, _now), 2);
      expect(filterNotifications(items, NotificationFilter.urgent), hasLength(2));
    });

    test('unknown id fails', () async {
      final result = await _mock().markAsRead('nope');
      expect(result, isA<Err<void>>());
    });
  });

  group('NotificationsController', () {
    test('loads newest first', () async {
      final container = _container(_mock());
      final items = await container.read(notificationsControllerProvider.future);
      for (var i = 1; i < items.length; i++) {
        expect(items[i].receivedAt.isAfter(items[i - 1].receivedAt), isFalse);
      }
      expect(container.read(unreadNotificationCountProvider), 3);
    });

    test('markAsRead updates the state and persists', () async {
      final repo = _mock();
      final container = _container(repo);
      final items = await container.read(notificationsControllerProvider.future);
      final firstUnread = items.firstWhere((n) => !n.isRead);

      final failure =
          await container.read(notificationsControllerProvider.notifier).markAsRead(firstUnread.id);

      expect(failure, isNull);
      expect(container.read(unreadNotificationCountProvider), 2);
      final stored = (await repo.getNotifications()).dataOrNull!;
      expect(stored.firstWhere((n) => n.id == firstUnread.id).isRead, isTrue);
    });

    test('markAsRead on a read notification is a no-op', () async {
      final container = _container(_ReadOnlyRepository());
      final items = await container.read(notificationsControllerProvider.future);
      final read = items.firstWhere((n) => n.isRead);
      final failure =
          await container.read(notificationsControllerProvider.notifier).markAsRead(read.id);
      expect(failure, isNull);
    });

    test('markAllAsRead clears the unread count', () async {
      final container = _container(_mock());
      await container.read(notificationsControllerProvider.future);

      final failure = await container.read(notificationsControllerProvider.notifier).markAllAsRead();

      expect(failure, isNull);
      expect(container.read(unreadNotificationCountProvider), 0);
    });

    test('a failed markAsRead is reverted', () async {
      final container = _container(_ReadOnlyRepository());
      final items = await container.read(notificationsControllerProvider.future);
      final id = items.firstWhere((n) => !n.isRead).id;

      final pending = container.read(notificationsControllerProvider.notifier).markAsRead(id);
      expect(container.read(unreadNotificationCountProvider), 2); // optimistic
      final failure = await pending;

      expect(failure, isA<NetworkFailure>());
      expect(container.read(unreadNotificationCountProvider), 3);
    });

    test('a failed markAllAsRead is reverted', () async {
      final container = _container(_ReadOnlyRepository());
      await container.read(notificationsControllerProvider.future);

      final failure = await container.read(notificationsControllerProvider.notifier).markAllAsRead();

      expect(failure, isA<ServerFailure>());
      expect(container.read(unreadNotificationCountProvider), 3);
    });
  });
}
