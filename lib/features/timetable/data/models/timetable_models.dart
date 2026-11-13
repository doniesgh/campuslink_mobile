import '../../domain/entities/class_session.dart';
import '../../domain/entities/timetable_week.dart';

// JSON from the timetable API (backend/src/modules/timetable). Dates are
// 'YYYY-MM-DD' and times wall-clock 'HH:mm', so the DateTimes are built here,
// in local time: 08:30 stays 08:30 whatever the phone's time zone.

/// Expected week JSON:
/// { "start": "2026-11-02", "days": [day x 7], "semester": 1, "classGroup": "Tech Track 4BI" }
TimetableWeek timetableWeekFromJson(Map<String, dynamic> json) => TimetableWeek(
      start: parseApiDate(json['start'] as String),
      days: [
        for (final d in json['days'] as List) timetableDayFromJson(d as Map<String, dynamic>),
      ],
      semester: (json['semester'] as num?)?.toInt(),
      classGroup: json['classGroup'] as String?,
    );

/// Expected day JSON:
/// { "date": "2026-11-05", "semesterWeek": 8, "sessions": [session...] }
TimetableDay timetableDayFromJson(Map<String, dynamic> json) => TimetableDay(
      date: parseApiDate(json['date'] as String),
      semesterWeek: (json['semesterWeek'] as num?)?.toInt(),
      sessions: [
        for (final s in json['sessions'] as List) classSessionFromJson(s as Map<String, dynamic>),
      ]..sort((a, b) => a.start.compareTo(b.start)),
    );

/// Expected session JSON:
/// { "id": "algo-2026-11-5", "course": "...", "room": "...", "teacher": "...",
///   "date": "2026-11-05", "start": "08:30", "end": "10:00", "kind": "lab",
///   "lectureNumber": null, "lectureCount": null, "coefficient": null, "notes": null,
///   "mode": "online", "meetUrl": "https://meet.google.com/abc-defg-hij" }
/// (`mode` and `meetUrl` are missing from older APIs: on campus.)
ClassSession classSessionFromJson(Map<String, dynamic> json) {
  final day = parseApiDate(json['date'] as String);
  return ClassSession(
    id: json['id'] as String,
    course: json['course'] as String,
    room: json['room'] as String,
    teacher: json['teacher'] as String,
    start: _at(day, json['start'] as String),
    end: _at(day, json['end'] as String),
    // An unknown kind (added later on the server) shows as a lecture.
    kind: SessionKind.values.asNameMap()[json['kind']] ?? SessionKind.lecture,
    lectureNumber: (json['lectureNumber'] as num?)?.toInt(),
    lectureCount: (json['lectureCount'] as num?)?.toInt(),
    coefficient: (json['coefficient'] as num?)?.toDouble(),
    notes: json['notes'] as String?,
    mode: sessionModeFromJson(json['mode']),
    meetUrl: json['meetUrl'] as String?,
  );
}

/// 'online' or on campus (also for a missing or unknown mode).
SessionMode sessionModeFromJson(Object? value) =>
    value == 'online' ? SessionMode.online : SessionMode.onsite;

/// [day] at the wall-clock time 'HH:mm'.
DateTime _at(DateTime day, String hm) {
  final parts = hm.split(':');
  return DateTime(day.year, day.month, day.day, int.parse(parts[0]), int.parse(parts[1]));
}

/// 'YYYY-MM-DD' -> that date at local midnight.
DateTime parseApiDate(String value) {
  final parts = value.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

/// The calendar date of [d] (as the student sees it) as 'YYYY-MM-DD'.
String formatApiDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
}
