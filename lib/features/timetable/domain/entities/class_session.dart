enum SessionKind { lecture, lab, exam, workshop }

/// Where a session stands relative to "now". Only the first upcoming
/// session of the day is [next]; the ones after it are [later].
enum SessionStatus { done, ongoing, next, later }

/// One class slot in the student's timetable.
class ClassSession {
  const ClassSession({
    required this.id,
    required this.course,
    required this.room,
    required this.teacher,
    required this.start,
    required this.end,
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
  final DateTime start;
  final DateTime end;
  final SessionKind kind;

  /// Position of this lecture in the course (e.g. 7 of 14), when known.
  final int? lectureNumber;
  final int? lectureCount;

  /// Weight of an evaluation in the course grade (e.g. 2.0), when known.
  final double? coefficient;

  /// Practical details ("Chapters 1–4 · Bring a calculator"), when any.
  final String? notes;

  Duration get duration => end.difference(start);

  bool isOverAt(DateTime now) => !end.isAfter(now);
  bool isOngoingAt(DateTime now) => !start.isAfter(now) && end.isAfter(now);

  /// 0..1 progress through the course, or null when unknown.
  double? get courseProgress {
    final n = lectureNumber, total = lectureCount;
    if (n == null || total == null || total <= 0) return null;
    return (n / total).clamp(0.0, 1.0);
  }
}

/// A day of the timetable.
class TimetableDay {
  const TimetableDay({
    required this.date,
    required this.sessions,
    this.semesterWeek,
  });

  final DateTime date;

  /// Sorted by start time.
  final List<ClassSession> sessions;

  /// 1-based week of the semester, or null outside a semester.
  final int? semesterWeek;
}

/// Status of each of [sessions] (sorted by start time) at [now].
List<SessionStatus> sessionStatuses(List<ClassSession> sessions, DateTime now) {
  final statuses = <SessionStatus>[];
  var nextFound = false;
  for (final s in sessions) {
    if (s.isOverAt(now)) {
      statuses.add(SessionStatus.done);
    } else if (s.isOngoingAt(now)) {
      statuses.add(SessionStatus.ongoing);
    } else if (!nextFound) {
      nextFound = true;
      statuses.add(SessionStatus.next);
    } else {
      statuses.add(SessionStatus.later);
    }
  }
  return statuses;
}
