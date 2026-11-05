import 'package:campuspulse/core/router/route_names.dart';
import 'package:campuspulse/features/notifications/domain/entities/app_notification.dart';
import 'package:campuspulse/features/notifications/domain/entities/notification_feed.dart';
import 'package:campuspulse/features/notifications/presentation/notification_routes.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 5, 10, 30); // Thursday

AppNotification _n(
  String id,
  DateTime at, {
  NotificationCategory category = NotificationCategory.academic,
  bool read = false,
  bool urgent = false,
}) =>
    AppNotification(
      id: id,
      category: category,
      label: id,
      title: id,
      body: id,
      receivedAt: at,
      isRead: read,
      isUrgent: urgent,
    );

List<String> _ids(Iterable<AppNotification> items) => [for (final n in items) n.id];

void main() {
  final items = [
    _n('room', _now.subtract(const Duration(minutes: 15)), urgent: true),
    _n('ride', _now.subtract(const Duration(hours: 1)), category: NotificationCategory.covoiturage),
    _n('exam', DateTime(2026, 11, 4, 14, 30), read: true),
    _n('lost', DateTime(2026, 11, 3, 7), category: NotificationCategory.lostFound, read: true, urgent: true),
    _n('job', DateTime(2026, 11, 1, 9), category: NotificationCategory.career),
  ];

  group('filterNotifications', () {
    test('all keeps everything in order', () {
      expect(_ids(filterNotifications(items, NotificationFilter.all)), _ids(items));
    });

    test('by category', () {
      expect(_ids(filterNotifications(items, NotificationFilter.academic)), ['room', 'exam']);
      expect(_ids(filterNotifications(items, NotificationFilter.covoiturage)), ['ride']);
    });

    test('urgent spans categories', () {
      expect(_ids(filterNotifications(items, NotificationFilter.urgent)), ['room', 'lost']);
    });

    test('empty input', () {
      expect(filterNotifications(const [], NotificationFilter.urgent), isEmpty);
    });
  });

  group('unread counts', () {
    test('unreadCount', () {
      expect(unreadCount(items), 3);
      expect(unreadCount(const []), 0);
    });

    test('unreadTodayCount only counts today', () {
      expect(unreadTodayCount(items, _now), 2);
      expect(unreadTodayCount(withReadState(items, {'room'}, isRead: true), _now), 1);
    });
  });

  group('groupOf', () {
    test('calendar days, not 24h windows', () {
      final lateNight = DateTime(2026, 11, 5, 0, 5);
      expect(groupOf(DateTime(2026, 11, 4, 23, 55), lateNight), NotificationGroup.yesterday);
      expect(groupOf(DateTime(2026, 11, 5, 0, 1), lateNight), NotificationGroup.today);
      expect(groupOf(DateTime(2026, 11, 3, 23, 59), _now), NotificationGroup.earlier);
    });

    test('future dates (clock skew) count as today', () {
      expect(groupOf(_now.add(const Duration(hours: 2)), _now), NotificationGroup.today);
    });

    test('across a month boundary', () {
      expect(
        groupOf(DateTime(2026, 10, 31, 20), DateTime(2026, 11, 1, 8)),
        NotificationGroup.yesterday,
      );
    });
  });

  group('groupByDay', () {
    test('sections in order, newest first inside each', () {
      final shuffled = [items[3], items[0], items[4], items[2], items[1]];
      final sections = groupByDay(shuffled, _now);
      expect([for (final s in sections) s.group], NotificationGroup.values);
      expect(_ids(sections[0].items), ['room', 'ride']);
      expect(_ids(sections[1].items), ['exam']);
      expect(_ids(sections[2].items), ['lost', 'job']);
    });

    test('skips empty sections', () {
      final sections = groupByDay([items[0], items[4]], _now);
      expect([for (final s in sections) s.group], [NotificationGroup.today, NotificationGroup.earlier]);
    });

    test('empty input gives no sections', () {
      expect(groupByDay(const [], _now), isEmpty);
    });
  });

  test('sortNewestFirst is stable for equal dates', () {
    final at = DateTime(2026, 11, 5, 9);
    final sorted = sortNewestFirst([_n('a', at), _n('b', _now), _n('c', at)]);
    expect(_ids(sorted), ['b', 'a', 'c']);
  });

  group('withReadState', () {
    test('marks only the given ids', () {
      final updated = withReadState(items, {'room', 'job'}, isRead: true);
      expect(unreadCount(updated), 1);
      expect(updated[1].isRead, isFalse);
      expect(_ids(updated), _ids(items));
    });

    test('keeps unchanged instances', () {
      final updated = withReadState(items, {'exam'}, isRead: true);
      expect(identical(updated[2], items[2]), isTrue);
    });

    test('can revert to unread', () {
      final reverted = withReadState(items, {'exam'}, isRead: false);
      expect(reverted[2].isRead, isFalse);
    });
  });

  group('notificationTimeLabel', () {
    test('today: relative', () {
      expect(notificationTimeLabel(_now.subtract(const Duration(minutes: 15)), _now), '15 min ago');
      expect(notificationTimeLabel(_now.subtract(const Duration(hours: 1)), _now), '1h ago');
    });

    test('yesterday: "Hier · HH:mm"', () {
      expect(notificationTimeLabel(DateTime(2026, 11, 4, 14, 30), _now), 'Hier · 14:30');
    });

    test('earlier: days ago, then date', () {
      expect(notificationTimeLabel(DateTime(2026, 11, 3, 7), _now), '2d ago');
      expect(notificationTimeLabel(DateTime(2026, 10, 20, 7), _now), '20/10');
    });
  });

  test('criticalUpdatesLabel', () {
    expect(criticalUpdatesLabel(2), '2 critical campus updates today');
    expect(criticalUpdatesLabel(1), '1 critical campus update today');
    expect(criticalUpdatesLabel(0), "You're all caught up today");
  });

  group('notificationRoute', () {
    NotificationLink link(NotificationDestination d, [String? id]) => NotificationLink(d, id: id);

    test('tab and nested destinations', () {
      expect(notificationRoute(link(NotificationDestination.home)), RoutePaths.home);
      expect(notificationRoute(link(NotificationDestination.timetable)), RoutePaths.timetable);
      expect(notificationRoute(link(NotificationDestination.forum)), RoutePaths.forum);
      expect(notificationRoute(link(NotificationDestination.courses)), RoutePaths.courses);
      expect(notificationRoute(link(NotificationDestination.grades)), RoutePaths.grades);
    });

    test('detail destinations need an id', () {
      expect(
        notificationRoute(link(NotificationDestination.ride, 'es-4091')),
        RoutePaths.ride('es-4091'),
      );
      expect(
        notificationRoute(link(NotificationDestination.job, 'instadeep-ml')),
        RoutePaths.job('instadeep-ml'),
      );
      expect(notificationRoute(link(NotificationDestination.ride)), isNull);
      expect(notificationRoute(link(NotificationDestination.job)), isNull);
    });
  });
}
