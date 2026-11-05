import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/features/timetable/data/repositories/mock_timetable_repository.dart';
import 'package:campuspulse/features/timetable/domain/entities/class_session.dart';
import 'package:flutter_test/flutter_test.dart';

ClassSession _session(String id, int startHour, int endHour) => ClassSession(
      id: id,
      course: id,
      room: 'Salle 1',
      teacher: 'Dr. X',
      start: DateTime(2026, 1, 5, startHour),
      end: DateTime(2026, 1, 5, endHour),
    );

void main() {
  final day = [
    _session('a', 8, 10),
    _session('b', 10, 12),
    _session('c', 13, 15),
    _session('d', 15, 17),
  ];

  group('sessionStatuses', () {
    test('during a class', () {
      expect(sessionStatuses(day, DateTime(2026, 1, 5, 11)), [
        SessionStatus.done,
        SessionStatus.ongoing,
        SessionStatus.next,
        SessionStatus.later,
      ]);
    });

    test('between classes, only the first upcoming one is next', () {
      expect(sessionStatuses(day, DateTime(2026, 1, 5, 12, 30)), [
        SessionStatus.done,
        SessionStatus.done,
        SessionStatus.next,
        SessionStatus.later,
      ]);
    });

    test('a class ending now is done', () {
      expect(sessionStatuses(day, DateTime(2026, 1, 5, 17)), everyElement(SessionStatus.done));
    });

    test('before the first class', () {
      expect(sessionStatuses(day, DateTime(2026, 1, 5, 7)).first, SessionStatus.next);
    });
  });

  test('courseProgress', () {
    final s = ClassSession(
      id: 'gl',
      course: 'Génie Logiciel',
      room: 'Amphi 3B',
      teacher: 'Prof. Ben Ali',
      start: DateTime(2026, 1, 5, 10),
      end: DateTime(2026, 1, 5, 12),
      lectureNumber: 7,
      lectureCount: 14,
    );
    expect(s.courseProgress, 0.5);
    expect(_session('x', 8, 9).courseProgress, isNull);
  });

  group('MockTimetableRepository', () {
    final repo = MockTimetableRepository();

    test('weekday: sorted sessions and semester week', () async {
      final result = await repo.getDay(DateTime(2026, 11, 5)); // Thursday
      final day = (result as Success<TimetableDay>).value;
      expect(day.semesterWeek, 8); // S1 starts on 15 September
      expect(day.sessions, isNotEmpty);
      for (var i = 1; i < day.sessions.length; i++) {
        expect(day.sessions[i].start.isAfter(day.sessions[i - 1].start), isTrue);
      }
    });

    test('weekend: no classes', () async {
      final result = await repo.getDay(DateTime(2026, 11, 7)); // Saturday
      expect((result as Success<TimetableDay>).value.sessions, isEmpty);
    });
  });
}
