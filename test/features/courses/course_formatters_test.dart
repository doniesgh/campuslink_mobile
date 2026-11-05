import 'package:campuspulse/features/courses/domain/course_logic.dart';
import 'package:campuspulse/features/courses/presentation/utils/course_formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatFileSize', () {
    expect(formatFileSize(4404019), '4.2 MB');
    expect(formatFileSize(10 * 1024 * 1024), '10 MB');
    expect(formatFileSize(820000), '801 KB');
    expect(formatFileSize(512), '512 B');
  });

  test('formatVideoLength', () {
    expect(formatVideoLength(const Duration(minutes: 45)), '45 mins');
    expect(formatVideoLength(const Duration(minutes: 1)), '1 min');
    expect(formatVideoLength(const Duration(minutes: 90)), '1h 30');
    expect(formatVideoLength(const Duration(hours: 2)), '2h');
  });

  test('formatMonthDay', () {
    expect(formatMonthDay(DateTime(2026, 10, 12)), 'Oct 12');
  });

  group('formatDueLabel', () {
    final now = DateTime(2026, 11, 5, 9); // Thursday

    test('today, weekday within a week, then the date', () {
      expect(formatDueLabel(DateTime(2026, 11, 5, 18), now), 'Due today 18:00');
      expect(formatDueLabel(DateTime(2026, 11, 6, 23, 59), now), 'Due Fri 23:59');
      expect(formatDueLabel(DateTime(2026, 11, 11, 8, 30), now), 'Due Wed 08:30');
      expect(formatDueLabel(DateTime(2026, 11, 12, 18), now), 'Due Nov 12 18:00');
    });

    test('past deadlines are overdue', () {
      expect(formatDueLabel(DateTime(2026, 11, 5, 9), now), 'Overdue');
      expect(formatDueLabel(DateTime(2026, 11, 4, 23, 59), now), 'Overdue');
    });
  });

  test('quizCountdown', () {
    final now = DateTime(2026, 11, 5, 9);
    expect(quizCountdown(DateTime(2026, 11, 9, 10, 15), now), (lead: 'in ', highlight: '4 days'));
    expect(quizCountdown(DateTime(2026, 11, 6, 8, 30), now), (lead: '', highlight: 'tomorrow'));
    expect(quizCountdown(DateTime(2026, 11, 5, 14), now), (lead: '', highlight: 'today'));
  });

  test('paceLabel', () {
    expect(paceLabel(CoursePace.ahead), 'Completed ahead of schedule');
    expect(paceLabel(CoursePace.onTrack), 'Right on schedule');
    expect(paceLabel(CoursePace.behind), 'Behind schedule, time to catch up');
  });

  test('count labels', () {
    expect(classmatesOnlineLabel(24), '24 classmates online right now');
    expect(classmatesOnlineLabel(1), '1 classmate online right now');
    expect(classmatesOnlineLabel(0), 'No classmates online right now');
    expect(filesCountLabel(3), '3 files');
    expect(filesCountLabel(1), '1 file');
  });

  test('validateRepoUrl', () {
    expect(validateRepoUrl(null), 'Paste your repository link');
    expect(validateRepoUrl('  '), 'Paste your repository link');
    expect(validateRepoUrl('github.com/me/lab'), 'Enter a valid https:// repository link');
    expect(validateRepoUrl('https://github.com/me/lab'), isNull);
  });
}
