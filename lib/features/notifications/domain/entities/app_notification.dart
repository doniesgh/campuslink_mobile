/// What a notification is about. Drives the icon and the filter chips.
enum NotificationCategory { academic, covoiturage, lostFound, career, community }

/// Screen a notification opens when tapped. Mapped to a route by the
/// presentation layer, so the domain stays free of router types.
enum NotificationDestination { home, timetable, courses, grades, forum, ride, job }

class NotificationLink {
  const NotificationLink(this.destination, {this.id});

  final NotificationDestination destination;

  /// Ride or job id for detail destinations.
  final String? id;
}

/// Extra block shown under the notification body.
sealed class NotificationAttachment {
  const NotificationAttachment();
}

/// Location snippet with a "Map pin" action (room changes...).
class PlaceAttachment extends NotificationAttachment {
  const PlaceAttachment(this.place);

  final String place;
}

/// Driver and car of a booked ride, with a "View Trip Details" action.
class RideAttachment extends NotificationAttachment {
  const RideAttachment({
    required this.driverName,
    required this.carLabel,
    this.isDriverVerified = false,
  });

  final String driverName;

  /// "Clio 4 · Blanc glacier"
  final String carLabel;
  final bool isDriverVerified;
}

/// "Download Schedule" and "Add to Calendar" actions (exam timetables...).
class ScheduleAttachment extends NotificationAttachment {
  const ScheduleAttachment();
}

/// Lost & found pickup status with a claim ticket.
class PickupAttachment extends NotificationAttachment {
  const PickupAttachment({required this.availability, required this.ticket});

  /// "Available for pickup until 17h00"
  final String availability;

  /// Ticket number, without the "#".
  final String ticket;
}

/// A campus notification (named to avoid clashing with Flutter's `Notification`).
class AppNotification {
  const AppNotification({
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

  final String id;
  final NotificationCategory category;

  /// Badge text: "Urgent Academic", "Covoiturage", "Registrar Notice"...
  final String label;
  final String title;

  /// Body with light markup: `**strong**`, `~~struck~~`, `==highlight==`.
  final String body;
  final DateTime receivedAt;
  final bool isRead;

  /// Shown under the "Urgent Alerts" filter, in coral.
  final bool isUrgent;
  final NotificationAttachment? attachment;

  /// Null when the notification does not open another screen.
  final NotificationLink? link;

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        category: category,
        label: label,
        title: title,
        body: body,
        receivedAt: receivedAt,
        isRead: isRead ?? this.isRead,
        isUrgent: isUrgent,
        attachment: attachment,
        link: link,
      );
}
