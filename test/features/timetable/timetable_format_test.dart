import 'package:campuspulse/features/timetable/domain/entities/class_session.dart';
import 'package:campuspulse/features/timetable/presentation/timetable_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatShortWeekday', () {
    expect(formatShortWeekday(DateTime(2026, 11, 2)), 'Mon');
    expect(formatShortWeekday(DateTime(2026, 11, 7)), 'Sat');
  });

  test('formatWeekRange covers Monday to Friday', () {
    expect(formatWeekRange(DateTime(2025, 5, 19)), 'May 19–23');
    expect(formatWeekRange(DateTime(2026, 4, 27)), 'Apr 27–May 1');
    expect(formatWeekRange(DateTime(2026, 12, 28)), 'Dec 28–Jan 1');
  });

  test('formatWeekLabel', () {
    expect(formatWeekLabel(DateTime(2025, 5, 19), semester: 2), 'May 19–23 · Semester 2');
    expect(formatWeekLabel(DateTime(2026, 7, 6)), 'Jul 6–10');
  });

  test('formatCompactDuration', () {
    expect(formatCompactDuration(const Duration(minutes: 50)), '50m');
    expect(formatCompactDuration(const Duration(minutes: 70)), '1h 10m');
    expect(formatCompactDuration(const Duration(hours: 2)), '2h');
    expect(formatCompactDuration(const Duration(hours: 7, minutes: 15)), '7h 15m');
    expect(formatCompactDuration(const Duration(seconds: 30)), '1m');
    expect(formatCompactDuration(const Duration(minutes: -5)), '0m');
    expect(formatCompactDuration(const Duration(minutes: 50, seconds: 30), roundUp: false), '50m');
    expect(formatCompactDuration(const Duration(seconds: 30), roundUp: false), '0m');
  });

  test('formatSessionLength', () {
    expect(formatSessionLength(const Duration(hours: 2)), '2 hrs');
    expect(formatSessionLength(const Duration(hours: 1)), '1 hr');
    expect(formatSessionLength(const Duration(minutes: 90)), '1h 30m');
    expect(formatSessionLength(const Duration(minutes: 45)), '45m');
  });

  test('summary counts', () {
    expect(formatSessionCount(0), 'No Sessions Scheduled');
    expect(formatSessionCount(1), '1 Session Scheduled');
    expect(formatSessionCount(4), '4 Sessions Scheduled');
    expect(formatExamCount(1, today: true), '1 Exam Today');
    expect(formatExamCount(2, today: false), '2 Exams');
  });

  test('session labels', () {
    expect(sessionKindLabel(SessionKind.lecture), 'Lecture');
    expect(sessionKindLabel(SessionKind.lab), 'Lab / TP');
    expect(sessionKindLabel(SessionKind.workshop), 'Workshop');
    expect(sessionKindLabel(SessionKind.exam), 'Important');
    expect(formatEvaluationLabel(2), '⚠️ Major Evaluation · Coeff 2.0');
    expect(formatEvaluationLabel(1.5), '⚠️ Major Evaluation · Coeff 1.5');
    expect(formatEvaluationLabel(null), '⚠️ Major Evaluation');
  });
}
