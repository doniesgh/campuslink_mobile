import '../../../core/router/route_names.dart';
import '../../../core/utils/formatters.dart';
import '../domain/entities/app_notification.dart';
import '../domain/entities/notification_feed.dart';

/// Route opened by a notification, or null when it has nowhere to go
/// (detail destination without an id).
///
/// The notifications page sits above the tab shell, so callers must use
/// `context.go`: pushing a route of the shell from here would stack a second
/// shell (go_router asserts).
String? notificationRoute(NotificationLink link) {
  final id = link.id;
  return switch (link.destination) {
    NotificationDestination.home => RoutePaths.home,
    NotificationDestination.timetable => RoutePaths.timetable,
    NotificationDestination.courses => RoutePaths.courses,
    NotificationDestination.grades => RoutePaths.grades,
    NotificationDestination.forum => RoutePaths.forum,
    NotificationDestination.ride => id == null ? null : RoutePaths.ride(id),
    NotificationDestination.job => id == null ? null : RoutePaths.job(id),
  };
}

/// "15 min ago" / "1h ago" today, "Hier · 14:30" yesterday, "2d ago" (or "05/11") before.
String notificationTimeLabel(DateTime receivedAt, DateTime now) =>
    switch (groupOf(receivedAt, now)) {
      NotificationGroup.yesterday => 'Hier · ${formatHm(receivedAt)}',
      _ => formatTimeAgo(receivedAt, now: now),
    };

String notificationGroupTitle(NotificationGroup group) => switch (group) {
      NotificationGroup.today => 'Today',
      NotificationGroup.yesterday => 'Yesterday',
      NotificationGroup.earlier => 'Earlier',
    };

/// "2 critical campus updates today" (count of unread notifications received today).
String criticalUpdatesLabel(int count) => switch (count) {
      0 => "You're all caught up today",
      1 => '1 critical campus update today',
      _ => '$count critical campus updates today',
    };
