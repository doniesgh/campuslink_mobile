import '../../../../core/error/result.dart';
import '../entities/app_notification.dart';

abstract interface class NotificationRepository {
  Future<Result<List<AppNotification>>> getNotifications();
  Future<Result<void>> markAsRead(String id);
  Future<Result<void>> markAllAsRead();
}
