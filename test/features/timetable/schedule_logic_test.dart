import 'package:campuspulse/features/timetable/domain/entities/class_session.dart';
import 'package:campuspulse/features/timetable/domain/schedule_logic.dart';
import 'package:flutter_test/flutter_test.dart';

ClassSession _session(
  String id,
  (int, int) start,
  (int, int) end, {
  DateTime? day,
  SessionKind kind = SessionKind.lecture,
}) {
  final d = day ?? DateTime(2026, 11, 5);
  return ClassSession(
    id: id,
    course: id,
    room: 'Salle 1',
    teacher: 'Dr. X',
    start: DateTime(d.year, d.month, d.day, start.$1, start.$2),
    end: DateTime(d.year, d.month, d.day, end.$1, end.$2),
    kind: kind,
  );
}

void main() {
  group('week math', () {
    test('weekStart is the Monday of the week, at midnight', () {
      expect(weekStart(DateTime(2026, 11, 5, 14, 30)), DateTime(2026, 11, 2)); // Thursday
      expect(weekStart(DateTime(2026, 11, 2)), DateTime(2026, 11, 2)); // Monday
      expect(weekStart(DateTime(2026, 11, 8, 23)), DateTime(2026, 11, 2)); // Sunday
      expect(weekStart(DateTime(2026, 4, 1)), DateTime(2026, 3, 30)); // across months
      expect(weekStart(DateTime(2027, 1, 1)), DateTime(2026, 12, 28)); // across years
    });

    test('daysFrom and addWeeks stay on midnight across DST changes', () {
      expect(daysFrom(DateTime(2026, 3, 28), 3), [
        DateTime(2026, 3, 28),
        DateTime(2026, 3, 29),
        DateTime(2026, 3, 30),
      ]);
      expect(addWeeks(DateTime(2026, 3, 23), 1), DateTime(2026, 3, 30));
      expect(addWeeks(DateTime(2026, 11, 5, 10), -1), DateTime(2026, 10, 29));
      expect(addWeeks(DateTime(2026, 12, 30), 1), DateTime(2027, 1, 6));
    });

    test('isSameDay ignores the time', () {
      expect(isSameDay(DateTime(2026, 11, 5, 8), DateTime(2026, 11, 5, 23, 59)), isTrue);
      expect(isSameDay(DateTime(2026, 11, 5), DateTime(2026, 11, 6)), isFalse);
    });

    test('defaultTimetableDay: today, or next Monday on Sundays', () {
      expect(defaultTimetableDay(DateTime(2026, 11, 5, 14)), DateTime(2026, 11, 5));
      expect(defaultTimetableDay(DateTime(2026, 11, 7, 9)), DateTime(2026, 11, 7)); // Saturday
      expect(defaultTimetableDay(DateTime(2026, 11, 8, 9)), DateTime(2026, 11, 9)); // Sunday
    });
  });

  group('dayStatuses', () {
    final day = DateTime(2026, 11, 5);
    final sessions = [
      _session('a', (8, 0), (10, 0)),
      _session('b', (10, 0), (12, 0)),
      _session('c', (13, 0), (15, 0)),
    ];

    test('today: done, ongoing and next', () {
      expect(dayStatuses(sessions, day, DateTime(2026, 11, 5, 11)), [
        SessionStatus.done,
        SessionStatus.ongoing,
        SessionStatus.next,
      ]);
    });

    test('a future day has no "next" session', () {
      expect(
        dayStatuses(sessions, day, DateTime(2026, 11, 4, 11)),
        everyElement(SessionStatus.later),
      );
    });

    test('a past day is done', () {
      expect(
        dayStatuses(sessions, day, DateTime(2026, 11, 6, 9)),
        everyElement(SessionStatus.done),
      );
    });
  });

  group('buildTimeline', () {
    test('inserts the lunch break, not the short gaps', () {
      final sessions = [
        _session('algo', (8, 30), (10, 0)),
        _session('gl', (10, 15), (12, 15)),
        _session('bd', (13, 30), (15, 30)),
        _session('exam', (16, 0), (18, 0), kind: SessionKind.exam),
      ];
      final statuses = List.filled(4, SessionStatus.later);
      final entries = buildTimeline(sessions, statuses);

      expect(entries, hasLength(5));
      expect(entries[0], isA<TimelineSession>());
      expect(entries[1], isA<TimelineSession>());
      final lunch = entries[2] as TimelineBreak;
      expect(lunch.start, DateTime(2026, 11, 5, 12, 15));
      expect(lunch.end, DateTime(2026, 11, 5, 13, 30));
      expect(lunch.length, const Duration(hours: 1, minutes: 15));
      expect(lunch.isLunch, isTrue);
      expect((entries[3] as TimelineSession).session.id, 'bd');
      expect((entries[4] as TimelineSession).session.id, 'exam');
    });

    test('keeps each session status', () {
      final sessions = [_session('a', (8, 0), (9, 0)), _session('b', (9, 0), (10, 0))];
      final entries = buildTimeline(sessions, [SessionStatus.done, SessionStatus.ongoing]);
      expect(
        entries.cast<TimelineSession>().map((e) => e.status),
        [SessionStatus.done, SessionStatus.ongoing],
      );
    });

    test('a break starts when the longest overlapping session ends', () {
      final sessions = [
        _session('long', (8, 0), (12, 0)),
        _session('inside', (9, 0), (10, 0)),
        _session('after', (13, 0), (14, 0)),
      ];
      final entries = buildTimeline(sessions, List.filled(3, SessionStatus.later));
      expect(entries, hasLength(4));
      final gap = entries[2] as TimelineBreak;
      expect(gap.start, DateTime(2026, 11, 5, 12));
      expect(gap.end, DateTime(2026, 11, 5, 13));
    });

    test('no break below the minimum gap', () {
      final sessions = [_session('a', (8, 0), (9, 0)), _session('b', (9, 30), (10, 0))];
      expect(buildTimeline(sessions, List.filled(2, SessionStatus.later)), hasLength(2));
      expect(
        buildTimeline(
          sessions,
          List.filled(2, SessionStatus.later),
          minBreak: const Duration(minutes: 30),
        ),
        hasLength(3),
      );
    });

    test('empty day', () {
      expect(buildTimeline(const [], const []), isEmpty);
    });
  });

  test('TimelineBreak.isLunch overlaps 12:00 – 14:00', () {
    TimelineBreak gap((int, int) from, (int, int) to) => TimelineBreak(
          start: DateTime(2026, 11, 5, from.$1, from.$2),
          end: DateTime(2026, 11, 5, to.$1, to.$2),
        );
    expect(gap((11, 30), (12, 30)).isLunch, isTrue);
    expect(gap((12, 15), (13, 30)).isLunch, isTrue);
    expect(gap((11, 0), (12, 0)).isLunch, isFalse);
    expect(gap((14, 0), (15, 0)).isLunch, isFalse);
    expect(gap((9, 0), (10, 0)).isLunch, isFalse);
  });

  test('summarizeDay', () {
    final summary = summarizeDay([
      _session('a', (8, 30), (10, 0)),
      _session('b', (10, 15), (12, 15)),
      _session('c', (13, 30), (15, 30)),
      _session('d', (16, 0), (18, 0), kind: SessionKind.exam),
    ]);
    expect(summary.sessions, 4);
    expect(summary.exams, 1);
    expect(summary.total, const Duration(hours: 7, minutes: 30));

    final empty = summarizeDay(const []);
    expect(empty.sessions, 0);
    expect(empty.exams, 0);
    expect(empty.total, Duration.zero);
  });

  group('sessionProgress', () {
    final s = _session('gl', (10, 15), (12, 15));

    test('during the session', () {
      final p = sessionProgress(s, DateTime(2026, 11, 5, 11, 5));
      expect(p.elapsed, const Duration(minutes: 50));
      expect(p.remaining, const Duration(hours: 1, minutes: 10));
      expect(p.progress, closeTo(50 / 120, 1e-9));
    });

    test('clamped before and after', () {
      final before = sessionProgress(s, DateTime(2026, 11, 5, 9));
      expect(before.elapsed, Duration.zero);
      expect(before.progress, 0);
      final after = sessionProgress(s, DateTime(2026, 11, 5, 13));
      expect(after.remaining, Duration.zero);
      expect(after.progress, 1);
    });
  });

  test('dayMarker', () {
    expect(dayMarker(const []), DayMarker.none);
    expect(dayMarker([_session('a', (8, 0), (9, 0))]), DayMarker.classes);
    expect(
      dayMarker([
        _session('a', (8, 0), (9, 0)),
        _session('b', (10, 0), (11, 0), kind: SessionKind.exam),
      ]),
      DayMarker.exam,
    );
  });
}
