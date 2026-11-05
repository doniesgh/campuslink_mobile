import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/core/utils/formatters.dart';
import 'package:campuspulse/features/timetable/data/repositories/mock_timetable_repository.dart';
import 'package:campuspulse/features/timetable/domain/entities/class_session.dart';
import 'package:campuspulse/features/timetable/domain/entities/timetable_week.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final repo = MockTimetableRepository();

  Future<TimetableWeek> week(DateTime day) async =>
      ((await repo.getWeek(day)) as Success<TimetableWeek>).value;

  test('getWeek returns Monday to Sunday of the week', () async {
    final w = await week(DateTime(2026, 11, 5, 15)); // Thursday
    expect(w.start, DateTime(2026, 11, 2));
    expect(w.days.map((d) => d.date), [
      for (var i = 2; i <= 8; i++) DateTime(2026, 11, i),
    ]);
    expect(w.semester, 1);
    expect(w.classGroup, isNotNull);
  });

  test('weekdays keep the 08:30, 10:15 and 13:30 classes; weekends are free', () async {
    final w = await week(DateTime(2026, 11, 2));
    for (final day in w.days) {
      final starts = day.sessions.map((s) => formatHm(s.start)).toList();
      if (day.date.weekday >= DateTime.saturday) {
        expect(starts, isEmpty);
      } else {
        expect(starts.take(3), ['08:30', '10:15', '13:30']);
        for (var i = 1; i < day.sessions.length; i++) {
          expect(day.sessions[i].start.isAfter(day.sessions[i - 1].start), isTrue);
        }
      }
    }
  });

  test('days differ: Monday ends with a graded evaluation', () async {
    final w = await week(DateTime(2026, 11, 2));
    final monday = w.days[0].sessions;
    final tuesday = w.days[1].sessions;
    final exam = monday.last;
    expect(exam.kind, SessionKind.exam);
    expect(exam.coefficient, 2.0);
    expect(exam.notes, isNotNull);
    expect(tuesday.any((s) => s.kind == SessionKind.exam), isFalse);
    expect(monday.map((s) => s.room), isNot(tuesday.map((s) => s.room)));
  });

  test('getWeek and getDay agree', () async {
    final w = await week(DateTime(2026, 11, 5));
    final day = ((await repo.getDay(DateTime(2026, 11, 5))) as Success<TimetableDay>).value;
    final fromWeek = w.dayOf(DateTime(2026, 11, 5));
    expect(fromWeek.semesterWeek, day.semesterWeek);
    expect(fromWeek.sessions.map((s) => (s.id, s.start, s.end)),
        day.sessions.map((s) => (s.id, s.start, s.end)));
  });

  test('semester of the week', () async {
    expect((await week(DateTime(2026, 5, 18))).semester, 2);
    expect((await week(DateTime(2026, 7, 6))).semester, isNull); // summer
    // S1 starts on Tuesday 15 September 2026: that week is in S1.
    expect((await week(DateTime(2026, 9, 14))).semester, 1);
  });

  test('dayOf a date outside the week is an empty day', () async {
    final w = await week(DateTime(2026, 11, 2));
    final other = w.dayOf(DateTime(2026, 12, 1, 10));
    expect(other.date, DateTime(2026, 12, 1));
    expect(other.sessions, isEmpty);
  });
}
