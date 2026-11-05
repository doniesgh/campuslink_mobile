import '../../../../core/error/result.dart';
import '../../domain/entities/class_session.dart';
import '../../domain/entities/timetable_week.dart';
import '../../domain/repositories/timetable_repository.dart';

/// In-memory fake. Replace with a Dio-based implementation when the API exists.
///
/// Every weekday has classes at 08:30, 10:15 and 13:30 (the courses change
/// from day to day); Monday and Thursday end with an evaluation at 16:00.
/// No classes on weekends.
class MockTimetableRepository implements TimetableRepository {
  static const _latency = Duration(milliseconds: 400);
  static const _classGroup = 'Tech Track 4BI';

  @override
  Future<Result<TimetableDay>> getDay(DateTime day) async {
    await Future<void>.delayed(_latency);
    return Success(_day(day));
  }

  @override
  Future<Result<TimetableWeek>> getWeek(DateTime day) async {
    await Future<void>.delayed(_latency);
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

  static TimetableDay _day(DateTime day) => TimetableDay(
        date: DateTime(day.year, day.month, day.day),
        semesterWeek: _semesterWeek(day),
        sessions: _sessions(day),
      );

  static List<ClassSession> _sessions(DateTime day) {
    final slots = _week[day.weekday] ?? const <_Slot>[];
    final key = '${day.year}-${day.month}-${day.day}';
    DateTime at((int, int) hm) => DateTime(day.year, day.month, day.day, hm.$1, hm.$2);
    return [
      for (final s in slots)
        ClassSession(
          id: '${s.id}-$key',
          course: s.course,
          room: s.room,
          teacher: s.teacher,
          start: at(s.start),
          end: at(s.end),
          kind: s.kind,
          lectureNumber: s.lectureNumber,
          lectureCount: s.lectureCount,
          coefficient: s.coefficient,
          notes: s.notes,
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

  /// Weekly template, by [DateTime.weekday].
  static const _week = <int, List<_Slot>>{
    DateTime.monday: [
      _Slot('algo-cm', 'Algorithmes & Complexité', 'Amphi A', 'Prof. Trabelsi', (8, 30), (10, 0),
          lectureNumber: 8, lectureCount: 14),
      _Slot('genie-logiciel-tp', 'Génie Logiciel & Architecture', 'Lab 204', 'Prof. Ben Ali',
          (10, 15), (12, 15),
          kind: SessionKind.lab),
      _Slot('nosql', 'Bases de Données Avancées (NoSQL)', 'Salle B12', 'Prof. Mansour', (13, 30),
          (15, 30),
          kind: SessionKind.workshop),
      _Slot('cc-reseaux', 'Contrôle Continu : Réseaux & Télécom', 'Grand Amphi C', 'Dr. Hammami',
          (16, 0), (18, 0),
          kind: SessionKind.exam,
          coefficient: 2.0,
          notes: 'Chapters 1–4 · Bring scientific calculator & Student ID'),
    ],
    DateTime.tuesday: [
      _Slot('algo', 'Algorithmes & Complexité', 'Lab 14', 'Dr. Fersi', (8, 30), (10, 0),
          kind: SessionKind.lab),
      _Slot('genie-logiciel', 'Génie Logiciel & Architecture', 'Amphi 3B', 'Prof. Ben Ali',
          (10, 15), (12, 15),
          lectureNumber: 7, lectureCount: 14),
      _Slot('bases-de-donnees', 'Bases de Données', 'Salle 208', 'Dr. Gharbi', (13, 30), (15, 30),
          lectureNumber: 9, lectureCount: 12),
    ],
    DateTime.wednesday: [
      _Slot('reseaux', 'Réseaux & Télécom', 'Amphi B', 'Dr. Hammami', (8, 30), (10, 0),
          lectureNumber: 9, lectureCount: 14),
      _Slot('flutter-tp', 'Développement Mobile (Flutter)', 'Lab 204', 'Ing. Jlassi', (10, 15),
          (12, 15),
          kind: SessionKind.lab),
      _Slot('pi', 'Projet Intégré (PI)', 'Salle B12', 'Prof. Mansour', (13, 30), (15, 30),
          kind: SessionKind.workshop),
    ],
    DateTime.thursday: [
      _Slot('algo', 'Algorithmes & Complexité', 'Lab 14', 'Dr. Fersi', (8, 30), (10, 0),
          kind: SessionKind.lab),
      _Slot('genie-logiciel', 'Génie Logiciel & Architecture', 'Amphi 3B', 'Prof. Ben Ali',
          (10, 15), (12, 15),
          lectureNumber: 8, lectureCount: 14),
      _Slot('bases-de-donnees', 'Bases de Données', 'Salle 208', 'Dr. Gharbi', (13, 30), (15, 30),
          lectureNumber: 10, lectureCount: 12),
      _Slot('exam-flutter', 'Examen TP : Développement Mobile', 'Lab 204', 'Ing. Jlassi', (16, 0),
          (17, 30),
          kind: SessionKind.exam,
          coefficient: 1.5,
          notes: 'Bring your laptop with the Flutter SDK installed'),
    ],
    DateTime.friday: [
      _Slot('stats', 'Probabilités & Statistiques', 'Amphi A', 'Dr. Ayari', (8, 30), (10, 0),
          lectureNumber: 10, lectureCount: 14),
      _Slot('reseaux-tp', 'Réseaux & Télécom', 'Lab 12', 'Dr. Hammami', (10, 15), (12, 15),
          kind: SessionKind.lab),
      _Slot('entrepreneuriat', 'Entrepreneuriat & Innovation', 'Espace Coworking', 'Mme. Karoui',
          (13, 30), (15, 30),
          kind: SessionKind.workshop),
    ],
  };
}

/// A session of the weekly template; times are (hour, minute).
class _Slot {
  const _Slot(
    this.id,
    this.course,
    this.room,
    this.teacher,
    this.start,
    this.end, {
    this.kind = SessionKind.lecture,
    this.lectureNumber,
    this.lectureCount,
    this.coefficient,
    this.notes,
  });

  final String id;
  final String course;
  final String room;
  final String teacher;
  final (int, int) start;
  final (int, int) end;
  final SessionKind kind;
  final int? lectureNumber;
  final int? lectureCount;
  final double? coefficient;
  final String? notes;
}
