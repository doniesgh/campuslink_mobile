import 'entities/class_session.dart';

// Week math, day statuses and the day timeline. Pure functions (unit-tested).
// Dates are built with the DateTime constructor (not Duration arithmetic) so
// daylight-saving changes never shift them off midnight.

/// [d] at midnight.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Monday of the week containing [d], at midnight.
DateTime weekStart(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday));

/// [count] consecutive days from [start], at midnight.
List<DateTime> daysFrom(DateTime start, int count) => [
      for (var i = 0; i < count; i++) DateTime(start.year, start.month, start.day + i),
    ];

/// [d] moved by [weeks] weeks (same weekday), at midnight.
DateTime addWeeks(DateTime d, int weeks) => DateTime(d.year, d.month, d.day + 7 * weeks);

/// The day the timetable opens on: today, or the next Monday on Sundays
/// (never a class day, and the day strip only shows Monday to Saturday).
DateTime defaultTimetableDay(DateTime now) => now.weekday == DateTime.sunday
    ? DateTime(now.year, now.month, now.day + 1)
    : dateOnly(now);

/// [sessionStatuses] for the sessions of [day]: only today's sessions can be
/// [SessionStatus.next]; on another day they are all done (past days) or
/// later (future days).
List<SessionStatus> dayStatuses(List<ClassSession> sessions, DateTime day, DateTime now) {
  final statuses = sessionStatuses(sessions, now);
  if (isSameDay(day, now)) return statuses;
  return [for (final s in statuses) s == SessionStatus.next ? SessionStatus.later : s];
}

/// One row of the day timeline: a session, or a free period between two.
sealed class TimelineEntry {
  const TimelineEntry();
}

final class TimelineSession extends TimelineEntry {
  const TimelineSession(this.session, this.status);

  final ClassSession session;
  final SessionStatus status;
}

final class TimelineBreak extends TimelineEntry {
  const TimelineBreak({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  Duration get length => end.difference(start);

  /// Overlaps lunch time (12:00 – 14:00).
  bool get isLunch =>
      start.isBefore(DateTime(start.year, start.month, start.day, 14)) &&
      end.isAfter(DateTime(start.year, start.month, start.day, 12));
}

/// Shorter gaps between sessions (e.g. the 15 min to change rooms) are not
/// shown as free periods.
const minTimelineBreak = Duration(minutes: 45);

/// [sessions] (sorted by start time, with their [statuses]) with a
/// [TimelineBreak] wherever there are at least [minBreak] between two of them.
List<TimelineEntry> buildTimeline(
  List<ClassSession> sessions,
  List<SessionStatus> statuses, {
  Duration minBreak = minTimelineBreak,
}) {
  assert(sessions.length == statuses.length);
  final entries = <TimelineEntry>[];
  DateTime? busyUntil;
  for (var i = 0; i < sessions.length; i++) {
    final s = sessions[i];
    final gapStart = busyUntil;
    if (gapStart != null && s.start.difference(gapStart) >= minBreak) {
      entries.add(TimelineBreak(start: gapStart, end: s.start));
    }
    entries.add(TimelineSession(s, statuses[i]));
    if (gapStart == null || s.end.isAfter(gapStart)) busyUntil = s.end;
  }
  return entries;
}

/// Totals shown in the summary banner.
typedef DaySummary = ({int sessions, int exams, Duration total});

DaySummary summarizeDay(List<ClassSession> sessions) => (
      sessions: sessions.length,
      exams: sessions.where((s) => s.kind == SessionKind.exam).length,
      total: sessions.fold(Duration.zero, (sum, s) => sum + s.duration),
    );

/// Time spent and left in [s] at [now], and the 0..1 progress.
typedef SessionProgress = ({Duration elapsed, Duration remaining, double progress});

SessionProgress sessionProgress(ClassSession s, DateTime now) {
  final total = s.duration;
  if (total <= Duration.zero) {
    return (elapsed: Duration.zero, remaining: Duration.zero, progress: 1.0);
  }
  final at = now.isBefore(s.start) ? s.start : (now.isAfter(s.end) ? s.end : now);
  final elapsed = at.difference(s.start);
  return (
    elapsed: elapsed,
    remaining: total - elapsed,
    progress: elapsed.inMicroseconds / total.inMicroseconds,
  );
}

/// The dot under a day in the day strip.
enum DayMarker { none, classes, exam }

DayMarker dayMarker(List<ClassSession> sessions) {
  if (sessions.any((s) => s.kind == SessionKind.exam)) return DayMarker.exam;
  return sessions.isEmpty ? DayMarker.none : DayMarker.classes;
}
