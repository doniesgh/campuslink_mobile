import 'app_notification.dart';

/// Where this phone gets push notifications from (the API's `platform`).
enum PushPlatform { android, ios }

/// A push notification received by the phone. The API sends one for each
/// notification it creates, with the notification's id and link as data.
class PushMessage {
  const PushMessage({
    required this.title,
    required this.body,
    this.notificationId,
    this.link,
  });

  /// From a Firebase message: its title and body, and the API's `data`
  /// (`notificationId`, `category`, `destination`, `targetId`, all strings).
  factory PushMessage.fromData({
    String? title,
    String? body,
    required Map<String, dynamic> data,
  }) {
    String? text(String key) {
      final value = data[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    final destination = NotificationDestination.values.asNameMap()[text('destination')];
    return PushMessage(
      title: title ?? '',
      body: body ?? '',
      notificationId: text('notificationId'),
      link: destination == null ? null : NotificationLink(destination, id: text('targetId')),
    );
  }

  final String title;

  /// Plain text (the API strips the **bold**/==highlight== markup).
  final String body;

  /// The notification's id in `GET /notifications`, to mark it as read.
  final String? notificationId;

  /// The screen it opens, or null for the notifications list.
  final NotificationLink? link;
}
