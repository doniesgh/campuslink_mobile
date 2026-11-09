import '../../domain/entities/app_notification.dart';

/// One notification of `GET /notifications` (the API sends a plain list):
/// ```json
/// {
///   "id": "ride-confirmed-es-4091", "category": "covoiturage",
///   "label": "Covoiturage", "title": "...", "body": "**13h15** ...",
///   "receivedAt": "2026-11-05T08:30:00.000Z", "isRead": false, "isUrgent": false,
///   "attachment": { "type": "ride", "driverName": "Sarra K.", "carLabel": "...", "isDriverVerified": true },
///   "link": { "destination": "ride", "id": "es-4091" }
/// }
/// ```
/// `attachment` is null or one of the types `place` {place}, `ride`
/// {driverName, carLabel, isDriverVerified}, `schedule` {} and `pickup`
/// {availability, ticket}. `link` is null or {destination, id}, with
/// `destination` a [NotificationDestination] name and `id` the ride, job or
/// user id.
///
/// Values added by a newer API are tolerated: an unknown category shows as
/// [NotificationCategory.community], an unknown attachment or destination is
/// dropped.
class AppNotificationModel {
  const AppNotificationModel({
    required this.id,
    required this.category,
    required this.label,
    required this.title,
    required this.body,
    required this.receivedAt,
    this.isRead = false,
    this.isUrgent = false,
    this.attachment,
    this.link,
  });

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) => AppNotificationModel(
        id: json['id'] as String,
        category: _byName(NotificationCategory.values, json['category']) ??
            NotificationCategory.community,
        label: json['label'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        receivedAt: DateTime.parse(json['receivedAt'] as String).toLocal(),
        isRead: (json['isRead'] as bool?) ?? false,
        isUrgent: (json['isUrgent'] as bool?) ?? false,
        attachment: _attachmentFromJson(json['attachment']),
        link: _linkFromJson(json['link']),
      );

  final String id;
  final NotificationCategory category;
  final String label;
  final String title;
  final String body;
  final DateTime receivedAt;
  final bool isRead;
  final bool isUrgent;
  final NotificationAttachment? attachment;
  final NotificationLink? link;

  AppNotification toEntity() => AppNotification(
        id: id,
        category: category,
        label: label,
        title: title,
        body: body,
        receivedAt: receivedAt,
        isRead: isRead,
        isUrgent: isUrgent,
        attachment: attachment,
        link: link,
      );
}

/// Parses the whole `GET /notifications` response.
List<AppNotification> notificationsFromJson(List<dynamic> json) => [
      for (final item in json)
        AppNotificationModel.fromJson(item as Map<String, dynamic>).toEntity(),
    ];

T? _byName<T extends Enum>(List<T> values, Object? name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

NotificationAttachment? _attachmentFromJson(Object? json) {
  if (json is! Map<String, dynamic>) return null;
  return switch (json['type']) {
    'place' => PlaceAttachment(json['place'] as String),
    'ride' => RideAttachment(
        driverName: json['driverName'] as String,
        carLabel: json['carLabel'] as String,
        isDriverVerified: (json['isDriverVerified'] as bool?) ?? false,
      ),
    'schedule' => const ScheduleAttachment(),
    'pickup' => PickupAttachment(
        availability: json['availability'] as String,
        ticket: json['ticket'] as String,
      ),
    _ => null,
  };
}

NotificationLink? _linkFromJson(Object? json) {
  if (json is! Map<String, dynamic>) return null;
  final destination = _byName(NotificationDestination.values, json['destination']);
  return destination == null ? null : NotificationLink(destination, id: json['id'] as String?);
}
