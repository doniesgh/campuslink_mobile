import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/features/auth/presentation/providers/auth_controller.dart';
import 'package:campuspulse/features/notifications/domain/entities/app_notification.dart';
import 'package:campuspulse/features/notifications/domain/repositories/notification_repository.dart';
import 'package:campuspulse/features/notifications/presentation/providers/notification_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers with a different (empty) list for each call, counting the calls.
class _CountingRepository implements NotificationRepository {
  int loads = 0;

  @override
  Future<Result<List<AppNotification>>> getNotifications() async {
    loads++;
    return const Success([]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('the notification list reloads when another student signs in', () async {
    final repository = _CountingRepository();
    final userId = StateProvider<String?>((ref) => 'student-a');
    final container = ProviderContainer(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(repository),
        currentUserIdProvider.overrideWith((ref) => ref.watch(userId)),
      ],
    );
    addTearDown(container.dispose);

    await container.read(notificationsControllerProvider.future);
    expect(repository.loads, 1);

    // Same student: the cached list is reused.
    await container.read(notificationsControllerProvider.future);
    expect(repository.loads, 1);

    // Student B signs in on the same phone.
    container.read(userId.notifier).state = 'student-b';
    await container.read(notificationsControllerProvider.future);
    expect(repository.loads, 2);
  });
}
