import 'class_session.dart';

/// A week of the timetable, Monday to Sunday.
class TimetableWeek {
  const TimetableWeek({
    required this.start,
    required this.days,
    this.semester,
    this.classGroup,
  });

  /// Monday, at midnight.
  final DateTime start;

  /// Monday to Sunday.
  final List<TimetableDay> days;

  /// 1 or 2, or null outside a semester.
  final int? semester;

  /// The student's class group (e.g. "Tech Track 4BI"), when known.
  final String? classGroup;

  /// The day of this week on [date], or an empty day if it is not in the week.
  TimetableDay dayOf(DateTime date) => days.firstWhere(
        (d) =>
            d.date.year == date.year && d.date.month == date.month && d.date.day == date.day,
        orElse: () => TimetableDay(
          date: DateTime(date.year, date.month, date.day),
          sessions: const [],
        ),
      );
}
