import 'app_notification.dart';

/// Filter chips of the notifications screen.
enum NotificationFilter { all, academic, covoiturage, urgent }

/// Day sections of the feed.
enum NotificationGroup { today, yesterday, earlier }

typedef NotificationSection = ({NotificationGroup group, List<AppNotification> items});

bool matchesFilter(AppNotification n, NotificationFilter filter) => switch (filter) {
      NotificationFilter.all => true,
      NotificationFilter.academic => n.category == NotificationCategory.academic,
      NotificationFilter.covoiturage => n.category == NotificationCategory.covoiturage,
      NotificationFilter.urgent => n.isUrgent,
    };

List<AppNotification> filterNotifications(
  List<AppNotification> items,
  NotificationFilter filter,
) =>
    [for (final n in items) if (matchesFilter(n, filter)) n];

/// Newest first; ties keep their original order.
List<AppNotification> sortNewestFirst(List<AppNotification> items) {
  final indexed = items.indexed.toList()
    ..sort((a, b) {
      final byDate = b.$2.receivedAt.compareTo(a.$2.receivedAt);
      return byDate != 0 ? byDate : a.$1.compareTo(b.$1);
    });
  return [for (final (_, n) in indexed) n];
}

int unreadCount(List<AppNotification> items) => items.where((n) => !n.isRead).length;

int _dayDiff(DateTime d, DateTime now) => DateTime(now.year, now.month, now.day)
    .difference(DateTime(d.year, d.month, d.day))
    .inDays;

/// Today / yesterday / earlier, by calendar day. Future dates count as today.
NotificationGroup groupOf(DateTime receivedAt, DateTime now) {
  final days = _dayDiff(receivedAt, now);
  if (days <= 0) return NotificationGroup.today;
  if (days == 1) return NotificationGroup.yesterday;
  return NotificationGroup.earlier;
}

/// Unread notifications received today (the "N critical campus updates today" line).
int unreadTodayCount(List<AppNotification> items, DateTime now) => items
    .where((n) => !n.isRead && groupOf(n.receivedAt, now) == NotificationGroup.today)
    .length;

/// Sections in today → yesterday → earlier order, newest first inside each.
/// Empty sections are left out.
List<NotificationSection> groupByDay(List<AppNotification> items, DateTime now) {
  final buckets = {for (final g in NotificationGroup.values) g: <AppNotification>[]};
  for (final n in sortNewestFirst(items)) {
    buckets[groupOf(n.receivedAt, now)]!.add(n);
  }
  return [
    for (final g in NotificationGroup.values)
      if (buckets[g]!.isNotEmpty) (group: g, items: buckets[g]!),
  ];
}

/// Copy of [items] where the notifications in [ids] have [isRead].
List<AppNotification> withReadState(
  List<AppNotification> items,
  Set<String> ids, {
  required bool isRead,
}) =>
    [
      for (final n in items)
        ids.contains(n.id) && n.isRead != isRead ? n.copyWith(isRead: isRead) : n,
    ];
