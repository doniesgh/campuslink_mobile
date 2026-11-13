import '../../../../core/error/result.dart';
import '../../domain/entities/class_session.dart';
import '../../domain/entities/timetable_week.dart';
import '../../domain/repositories/timetable_repository.dart';
import 'mock_timetable_store.dart';

/// In-memory fake of the timetable API, on the weekly classes of [store]
/// (which the admin screens edit in demo mode).
///
/// Every weekday has classes at 08:30, 10:15 and 13:30 (the courses change
/// from day to day); Monday and Thursday end with an evaluation at 16:00;
/// Friday's workshop is online. No classes on weekends.
class MockTimetableRepository implements TimetableRepository {
  MockTimetableRepository({MockTimetableStore? store, this.latency = _latency})
      : store = store ?? MockTimetableStore();

  static const _latency = Duration(milliseconds: 400);
  static const _classGroup = MockTimetableStore.classGroup;

  final MockTimetableStore store;

  /// Fake network latency (zero: answers without a timer).
  final Duration latency;

  Future<void> _wait() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  @override
  Future<Result<TimetableDay>> getDay(DateTime day) async {
    await _wait();
    return Success(_day(day));
  }

  @override
  Future<Result<TimetableWeek>> getWeek(DateTime day) async {
    await _wait();
    final monday = DateTime(day.year, day.month, day.day - (day.weekday - DateTime.monday));
    final dates = [
      for (var i = 0; i < 7; i++) DateTime(monday.year, monday.month, monday.day + i),
    ];
    return Success(
      TimetableWeek(
        start: monday,
        days: [for (final d in dates) _day(d)],
        semester: dates.take(5).map(_semester).nonNulls.firstOrNull,
        classGroup: _classGroup,
      ),
    );
  }

  TimetableDay _day(DateTime day) => TimetableDay(
        date: DateTime(day.year, day.month, day.day),
        semesterWeek: _semesterWeek(day),
        sessions: _sessions(day),
      );

  List<ClassSession> _sessions(DateTime day) {
    final key = '${day.year}-${day.month}-${day.day}';
    DateTime at(String hm) => DateTime(
          day.year, day.month, day.day, int.parse(hm.substring(0, 2)), int.parse(hm.substring(3)),
        );
    return [
      for (final s in store.slots)
        if (s.weekday == day.weekday)
          ClassSession(
            id: '${s.id}-$key',
            course: s.course,
            // Like the API: "Online" for an online class without a room.
            room: s.room.isEmpty && s.isOnline ? 'Online' : s.room,
            teacher: s.teacher,
            start: at(s.start),
            end: at(s.end),
            kind: s.kind,
            lectureNumber: s.lectureNumber,
            lectureCount: s.lectureCount,
            coefficient: s.coefficient,
            notes: s.notes,
            mode: s.mode,
            meetUrl: s.isOnline ? s.meetUrl : null,
          ),
    ]..sort((a, b) => a.start.compareTo(b.start));
  }

  /// Mock academic calendar: S1 starts on 15 September, S2 on 2 February,
  /// 16 weeks each.
  static int? _semesterWeek(DateTime day) {
    final d = DateTime.utc(day.year, day.month, day.day);
    final start = day.month >= 9
        ? DateTime.utc(day.year, 9, 15)
        : day.month >= 2
            ? DateTime.utc(day.year, 2, 2)
            : DateTime.utc(day.year - 1, 9, 15);
    final days = d.difference(start).inDays;
    if (days < 0) return null;
    final week = days ~/ 7 + 1;
    return week <= 16 ? week : null;
  }

  /// 1 or 2 during a semester (same calendar as [_semesterWeek]), else null.
  static int? _semester(DateTime day) {
    if (_semesterWeek(day) == null) return null;
    return day.month >= 9 || day.month < 2 ? 1 : 2;
  }
}
