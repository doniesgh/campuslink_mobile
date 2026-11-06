import 'package:dio/dio.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../models/app_notification_model.dart';

/// Real implementation talking to the Node.js API. Read states live on the
/// server; the controller updates the screen first and reverts on failure.
class NotificationRepositoryImpl implements NotificationRepository {
  const NotificationRepositoryImpl(this._dio);
  final Dio _dio;

  /// The signed-in student's notifications, newest first.
  @override
  Future<Result<List<AppNotification>>> getNotifications() => guard(() async {
        final r = await _dio.get(ApiEndpoints.notifications);
        return notificationsFromJson(r.data as List<dynamic>);
      });

  /// 204 on success. A notification the student doesn't have answers 404
  /// (a [ServerFailure] with the API's message).
  @override
  Future<Result<void>> markAsRead(String id) => guard(() async {
        await _dio.post(ApiEndpoints.notificationRead(Uri.encodeComponent(id)));
      });

  @override
  Future<Result<void>> markAllAsRead() => guard(() async {
        await _dio.post(ApiEndpoints.notificationsReadAll);
      });
}
