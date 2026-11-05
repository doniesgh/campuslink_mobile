import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../data/repositories/mock_notification_repository.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/entities/notification_feed.dart';
import '../../domain/repositories/notification_repository.dart';

/// Swap MockNotificationRepository for the Dio-based implementation when the API is ready.
final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) => MockNotificationRepository());

/// All notifications, newest first, with their read state.
/// Kept alive so the unread count is available outside the notifications screen.
final notificationsControllerProvider =
    AsyncNotifierProvider<NotificationsController, List<AppNotification>>(
  NotificationsController.new,
);

/// Unread notifications (0 while loading). Handy for a badge on the Home bell.
final unreadNotificationCountProvider = Provider<int>(
  (ref) => unreadCount(ref.watch(notificationsControllerProvider).valueOrNull ?? const []),
);

/// Selected filter chip on the notifications screen.
final notificationFilterProvider =
    StateProvider.autoDispose<NotificationFilter>((ref) => NotificationFilter.all);

class NotificationsController extends AsyncNotifier<List<AppNotification>> {
  NotificationRepository get _repo => ref.read(notificationRepositoryProvider);

  @override
  Future<List<AppNotification>> build() async => sortNewestFirst(
        (await ref.watch(notificationRepositoryProvider).getNotifications()).unwrap(),
      );

  /// Reloads the list (pull to refresh). Errors are exposed through the state.
  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // The page shows the error state.
    }
  }

  /// Optimistic: the UI updates at once and is reverted on failure.
  /// Returns the [Failure], or null on success (or when there is nothing to do).
  Future<Failure?> markAsRead(String id) async {
    final items = state.valueOrNull;
    if (items == null || !items.any((n) => n.id == id && !n.isRead)) return null;
    return _markRead({id}, () => _repo.markAsRead(id));
  }

  Future<Failure?> markAllAsRead() async {
    final items = state.valueOrNull;
    if (items == null) return null;
    final ids = {for (final n in items) if (!n.isRead) n.id};
    if (ids.isEmpty) return null;
    return _markRead(ids, _repo.markAllAsRead);
  }

  Future<Failure?> _markRead(Set<String> ids, Future<Result<void>> Function() call) async {
    _setRead(ids, isRead: true);
    Failure? failure;
    try {
      failure = (await call()).when(success: (_) => null, failure: (f) => f);
    } catch (_) {
      failure = const UnknownFailure();
    }
    if (failure != null) _setRead(ids, isRead: false);
    return failure;
  }

  void _setRead(Set<String> ids, {required bool isRead}) {
    final items = state.valueOrNull;
    if (items == null) return;
    state = AsyncData(withReadState(items, ids, isRead: isRead));
  }
}
