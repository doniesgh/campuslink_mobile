import '../../../../core/error/result.dart';
import '../../domain/entities/class_session.dart';
import '../../domain/repositories/timetable_repository.dart';

/// In-memory fake. Replace with a Dio-based implementation when the API exists.
class MockTimetableRepository implements TimetableRepository {
  static const _latency = Duration(milliseconds: 400);

  @override
  Future<Result<TimetableDay>> getDay(DateTime day) async {
    await Future<void>.delayed(_latency);
    DateTime at(int h, int m) => DateTime(day.year, day.month, day.day, h, m);
    final weekend = day.weekday >= DateTime.saturday;

    return Success(
      TimetableDay(
        date: DateTime(day.year, day.month, day.day),
        semesterWeek: _semesterWeek(day),
        sessions: weekend
            ? const []
            : [
                ClassSession(
                  id: 'algo',
                  course: 'Algorithmes & Complexité',
                  room: 'Lab 14',
                  teacher: 'Dr. Fersi',
                  start: at(8, 30),
                  end: at(10, 0),
                  kind: SessionKind.lab,
                ),
                ClassSession(
                  id: 'genie-logiciel',
                  course: 'Génie Logiciel & Architecture',
                  room: 'Amphi 3B',
                  teacher: 'Prof. Ben Ali',
                  start: at(10, 15),
                  end: at(12, 15),
                  lectureNumber: 7,
                  lectureCount: 14,
                ),
                ClassSession(
                  id: 'bases-de-donnees',
                  course: 'Bases de Données',
                  room: 'Salle 208',
                  teacher: 'Dr. Gharbi',
                  start: at(13, 30),
                  end: at(15, 30),
                  lectureNumber: 9,
                  lectureCount: 12,
                ),
              ],
      ),
    );
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
}
