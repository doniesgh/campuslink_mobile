import '../domain/entities/class_session.dart';

// Text formatting specific to the timetable screen (unit-tested).

const _shortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _shortWeekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Mon", "Tue"...
String formatShortWeekday(DateTime d) => _shortWeekdays[d.weekday - 1];

/// Monday to Friday of the week starting on [monday]:
/// "May 19–23", "Apr 28–May 2".
String formatWeekRange(DateTime monday) {
  final friday = DateTime(monday.year, monday.month, monday.day + 4);
  final start = '${_shortMonths[monday.month - 1]} ${monday.day}';
  return monday.month == friday.month
      ? '$start–${friday.day}'
      : '$start–${_shortMonths[friday.month - 1]} ${friday.day}';
}

/// "May 19–23 · Semester 2", or just the range outside a semester.
String formatWeekLabel(DateTime monday, {int? semester}) => semester == null
    ? formatWeekRange(monday)
    : '${formatWeekRange(monday)} · Semester $semester';

/// "50m", "1h 10m", "2h". Rounded up to the minute, or down with
/// [roundUp] false; negative durations count as zero.
String formatCompactDuration(Duration d, {bool roundUp = true}) {
  final seconds = d.isNegative ? 0 : d.inSeconds;
  final minutes = roundUp ? (seconds / 60).ceil() : seconds ~/ 60;
  final h = minutes ~/ 60, m = minutes % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

/// Length of a session: "2 hrs", "1 hr", "1h 30m".
String formatSessionLength(Duration d) {
  final minutes = d.inMinutes;
  if (minutes > 0 && minutes % 60 == 0) {
    final h = minutes ~/ 60;
    return h == 1 ? '1 hr' : '$h hrs';
  }
  return formatCompactDuration(d);
}

/// "4 Sessions Scheduled" / "1 Session Scheduled" / "No Sessions Scheduled".
String formatSessionCount(int count) => switch (count) {
      0 => 'No Sessions Scheduled',
      1 => '1 Session Scheduled',
      _ => '$count Sessions Scheduled',
    };

/// "1 Exam Today" / "2 Exams" (without "Today" on other days).
String formatExamCount(int count, {required bool today}) =>
    '$count Exam${count == 1 ? '' : 's'}${today ? ' Today' : ''}';

/// The small uppercase label above a session title.
String sessionKindLabel(SessionKind kind) => switch (kind) {
      SessionKind.lecture => 'Lecture',
      SessionKind.lab => 'Lab / TP',
      SessionKind.workshop => 'Workshop',
      SessionKind.exam => 'Important',
    };

/// "⚠️ Major Evaluation · Coeff 2.0"
String formatEvaluationLabel(double? coefficient) => coefficient == null
    ? '⚠️ Major Evaluation'
    : '⚠️ Major Evaluation · Coeff ${coefficient.toStringAsFixed(1)}';
