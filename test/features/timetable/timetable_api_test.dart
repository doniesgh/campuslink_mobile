import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:campuspulse/core/error/failures.dart';
import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/features/timetable/data/models/timetable_models.dart';
import 'package:campuspulse/features/timetable/data/repositories/mock_timetable_repository.dart';
import 'package:campuspulse/features/timetable/data/repositories/timetable_repository_impl.dart';
import 'package:campuspulse/features/timetable/domain/entities/class_session.dart';
import 'package:campuspulse/features/timetable/domain/entities/timetable_week.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// A real `GET /api/timetable/week?date=2026-11-05` response, produced by the
/// backend tests (backend/test/timetable.test.ts, seeded demo template).
Map<String, dynamic> _weekFixture() => jsonDecode(
      File('test/features/timetable/fixtures/timetable_week.json').readAsStringSync(),
    ) as Map<String, dynamic>;

/// Answers every request with [respond] and records it.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);

  final (int, Object?) Function(RequestOptions options) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = respond(options);
    if (body == null) return ResponseBody.fromString('', status);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(TimetableRepositoryImpl, _FakeAdapter) _repo((int, Object?) Function(RequestOptions) respond) {
  final adapter = _FakeAdapter(respond);
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api'))..httpClientAdapter = adapter;
  return (TimetableRepositoryImpl(dio), adapter);
}

void main() {
  group('backend JSON', () {
    test('parses into the week the app shows', () {
      final week = timetableWeekFromJson(_weekFixture());

      expect(week.start, DateTime(2026, 11, 2));
      expect(week.days.map((d) => d.date), [
        for (var i = 2; i <= 8; i++) DateTime(2026, 11, i),
      ]);
      expect(week.semester, 1);
      expect(week.classGroup, 'Tech Track 4BI');
      expect(week.days.map((d) => d.semesterWeek), [7, 8, 8, 8, 8, 8, 8]);
      expect(week.days.map((d) => d.sessions.length), [4, 3, 3, 4, 3, 0, 0]);

      final first = week.days[0].sessions.first;
      expect(first.id, 'algo-cm-2026-11-2');
      expect(first.course, 'Algorithmes & Complexité');
      expect(first.room, 'Amphi A');
      expect(first.teacher, 'Prof. Trabelsi');
      // Wall-clock times, in local time whatever the time zone.
      expect(first.start, DateTime(2026, 11, 2, 8, 30));
      expect(first.end, DateTime(2026, 11, 2, 10));
      expect(first.kind, SessionKind.lecture);
      expect(first.courseProgress, closeTo(8 / 14, 1e-9));
      expect(first.coefficient, isNull);

      final exam = week.days[0].sessions.last;
      expect(exam.kind, SessionKind.exam);
      expect(exam.coefficient, 2.0);
      expect(exam.duration, const Duration(hours: 2));
      expect(exam.notes, 'Chapters 1–4 · Bring scientific calculator & Student ID');
      expect(first.mode, SessionMode.onsite);
      expect(first.isOnline, isFalse);
      expect(first.meetUrl, isNull);

      // Friday's workshop is online, with its Google Meet link.
      final online = week.days[4].sessions.last;
      expect(online.isOnline, isTrue);
      expect(online.room, 'Online');
      expect(online.meetUrl, 'https://meet.google.com/xqd-fkzw-pnb');
    });

    test('sessions of an older API (no mode) are on campus', () {
      final json = (_weekFixture()['days'] as List).first as Map<String, dynamic>;
      final session =
          Map<String, dynamic>.of((json['sessions'] as List).first as Map<String, dynamic>)
            ..remove('mode')
            ..remove('meetUrl');
      final parsed = classSessionFromJson(session);
      expect(parsed.mode, SessionMode.onsite);
      expect(parsed.meetUrl, isNull);
    });

    test('matches the mock repository session for session', () async {
      final api = timetableWeekFromJson(_weekFixture());
      final mock = (await MockTimetableRepository().getWeek(DateTime(2026, 11, 5))).unwrap();

      expect(api.start, mock.start);
      expect(api.semester, mock.semester);
      expect(api.classGroup, mock.classGroup);
      for (var i = 0; i < 7; i++) {
        final a = api.days[i], m = mock.days[i];
        expect(a.date, m.date);
        expect(a.semesterWeek, m.semesterWeek);
        expect(a.sessions.map(_describe), m.sessions.map(_describe));
      }
    });

    test('an unknown session kind shows as a lecture', () {
      final json = (_weekFixture()['days'] as List).first as Map<String, dynamic>;
      final session =
          Map<String, dynamic>.of((json['sessions'] as List).first as Map<String, dynamic>)
        ..['kind'] = 'hackathon';
      expect(classSessionFromJson(session).kind, SessionKind.lecture);
    });
  });

  group('API dates', () {
    test('format and parse calendar dates', () {
      expect(formatApiDate(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
      expect(parseApiDate('2026-01-05'), DateTime(2026, 1, 5));
    });
  });

  group('TimetableRepositoryImpl', () {
    final fixture = _weekFixture();
    final thursday = (fixture['days'] as List)[3] as Map<String, dynamic>;

    test('getDay sends the local calendar date', () async {
      final (repo, adapter) = _repo((_) => (200, thursday));
      final day = (await repo.getDay(DateTime(2026, 11, 5, 23, 30))).unwrap();

      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.uri.path, '/api/timetable/day');
      expect(adapter.requests.single.uri.queryParameters, {'date': '2026-11-05'});
      expect(day.date, DateTime(2026, 11, 5));
      expect(day.sessions.map((s) => s.id), [
        'algo-thu-2026-11-5',
        'genie-logiciel-thu-2026-11-5',
        'bases-de-donnees-thu-2026-11-5',
        'exam-flutter-2026-11-5',
      ]);
    });

    test('getWeek parses the week', () async {
      final (repo, adapter) = _repo((_) => (200, fixture));
      final week = (await repo.getWeek(DateTime(2026, 11, 2))).unwrap();

      expect(adapter.requests.single.uri.path, '/api/timetable/week');
      expect(adapter.requests.single.uri.queryParameters, {'date': '2026-11-02'});
      expect(week, isA<TimetableWeek>());
      expect(week.dayOf(DateTime(2026, 11, 5)).sessions, hasLength(4));
    });

    test('server errors become failures with the server message', () async {
      final (repo, _) = _repo((_) => (422, {'message': 'Pass the date as YYYY-MM-DD'}));
      final result = await repo.getDay(DateTime(2026, 11, 5));
      final failure = (result as Err<TimetableDay>).failure;
      expect(failure, isA<ValidationFailure>());
      expect(failure.message, 'Pass the date as YYYY-MM-DD');
    });
  });
}

/// Every field of a session, to compare two of them.
List<Object?> _describe(ClassSession s) => [
      s.id,
      s.course,
      s.room,
      s.teacher,
      s.start,
      s.end,
      s.kind,
      s.lectureNumber,
      s.lectureCount,
      s.coefficient,
      s.notes,
      s.mode,
      s.meetUrl,
    ];
