import 'dart:convert';

import 'package:campuspulse/core/router/route_names.dart';
import 'package:campuspulse/features/notifications/data/models/app_notification_model.dart';
import 'package:campuspulse/features/notifications/data/repositories/mock_notification_repository.dart';
import 'package:campuspulse/features/notifications/domain/entities/app_notification.dart';
import 'package:campuspulse/features/notifications/domain/entities/notification_feed.dart';
import 'package:campuspulse/features/notifications/presentation/notification_routes.dart';
import 'package:flutter_test/flutter_test.dart';

import 'notifications_api_fixture.dart';

List<AppNotification> _parse(String json) => notificationsFromJson(jsonDecode(json) as List<dynamic>);

/// Entities have no `==`: compare everything but the time as text.
String _describe(AppNotification n) {
  final attachment = switch (n.attachment) {
    null => 'none',
    PlaceAttachment(:final place) => 'place($place)',
    RideAttachment(:final driverName, :final carLabel, :final isDriverVerified) =>
      'ride($driverName, $carLabel, verified: $isDriverVerified)',
    ScheduleAttachment() => 'schedule',
    PickupAttachment(:final availability, :final ticket) => 'pickup($availability, #$ticket)',
  };
  final link = n.link == null ? 'none' : '${n.link!.destination.name}(${n.link!.id})';
  return [
    n.id,
    n.category.name,
    n.label,
    n.title,
    n.body,
    'read: ${n.isRead}',
    'urgent: ${n.isUrgent}',
    attachment,
    link,
  ].join(' | ');
}

void main() {
  group('seeded demo feed (real API response)', () {
    final items = _parse(seededNotificationsJson);

    test('has the content of the mock, field by field', () async {
      final mock = (await MockNotificationRepository(latency: Duration.zero).getNotifications())
          .dataOrNull!;
      expect(items.map(_describe), mock.map(_describe));
    });

    test('9 notifications, 3 unread, 2 urgent, newest first', () {
      expect(items, hasLength(9));
      expect(unreadCount(items), 3);
      expect(filterNotifications(items, NotificationFilter.urgent), hasLength(2));
      expect(sortNewestFirst(items).map((n) => n.id), items.map((n) => n.id));
    });

    test('times are UTC instants shown in local time', () {
      final first = items.first.receivedAt;
      expect(first.isUtc, isFalse);
      expect(first.toUtc(), DateTime.utc(2026, 11, 5, 9, 15));
      // "Yesterday 14:30" in Tunis (UTC+1).
      expect(items[2].receivedAt.toUtc(), DateTime.utc(2026, 11, 4, 13, 30));
      expect(items.last.receivedAt.toUtc(), DateTime.utc(2026, 10, 31, 5, 30));

      // Relative to the seed time (10:30 in Tunis): 2 unread today.
      final now = DateTime.utc(2026, 11, 5, 9, 30).toLocal();
      expect(unreadTodayCount(items, now), 2);
    });

    test('links open the ride, the job and the tabs', () {
      final routes = {for (final n in items) n.id: notificationRoute(n.link!)};
      expect(routes['ride-confirmed-es-4091'], RoutePaths.ride('es-4091'));
      expect(routes['job-instadeep-viewed'], RoutePaths.job('instadeep-ml'));
      expect(routes['room-change-gl'], RoutePaths.timetable);
      expect(routes['grade-bdd'], RoutePaths.grades);
      expect(routes['course-material-gl'], RoutePaths.courses);
      expect(routes['forum-reply'], RoutePaths.forum);
    });
  });

  test('welcome notification of a new student (real API response)', () {
    final items = _parse(welcomeNotificationsJson);
    expect(items.map(_describe), [
      'welcome | community | CampusPulse | Welcome to CampusPulse | '
          'Your timetable, rides, jobs and grades now live in one place. Campus alerts such as '
          '**room changes** and **new grades** will show up here. | '
          'read: false | urgent: false | none | none',
    ]);
    expect(items.single.receivedAt.toUtc(), DateTime.utc(2026, 11, 6, 19, 39, 1, 542));
  });

  group('values a newer API might add', () {
    Map<String, dynamic> json(Map<String, dynamic> overrides) => {
          'id': 'n1',
          'category': 'academic',
          'label': 'Grades',
          'title': 'T',
          'body': 'B',
          'receivedAt': '2026-11-05T09:15:00.000Z',
          ...overrides,
        };

    test('missing optional fields use defaults', () {
      final n = AppNotificationModel.fromJson(json({})).toEntity();
      expect(_describe(n), 'n1 | academic | Grades | T | B | read: false | urgent: false | none | none');
    });

    test('unknown category, attachment and destination do not break the feed', () {
      final n = AppNotificationModel.fromJson(json({
        'category': 'sports',
        'attachment': {'type': 'poll', 'question': '?'},
        'link': {'destination': 'library', 'id': null},
      })).toEntity();
      expect(n.category, NotificationCategory.community);
      expect(n.attachment, isNull);
      expect(n.link, isNull);
    });
  });
}
