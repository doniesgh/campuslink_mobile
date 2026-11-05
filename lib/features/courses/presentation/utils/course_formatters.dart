import '../../../../core/utils/formatters.dart';
import '../../domain/course_logic.dart';

const _shortWeekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _shortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// 4404019 -> "4.2 MB", 820000 -> "801 KB", 10485760 -> "10 MB"
String formatFileSize(int bytes) {
  const kb = 1024, mb = 1024 * 1024;
  if (bytes >= mb) {
    final s = (bytes / mb).toStringAsFixed(1);
    return '${s.endsWith('.0') ? s.substring(0, s.length - 2) : s} MB';
  }
  if (bytes >= kb) return '${(bytes / kb).round()} KB';
  return '$bytes B';
}

/// 45 min -> "45 mins", 1 min -> "1 min", 90 min -> "1h 30", 2h -> "2h"
String formatVideoLength(Duration d) {
  final minutes = d.inMinutes;
  if (minutes < 60) return '$minutes min${minutes == 1 ? '' : 's'}';
  final rest = minutes % 60;
  return rest == 0 ? '${minutes ~/ 60}h' : '${minutes ~/ 60}h ${rest.toString().padLeft(2, '0')}';
}

/// "Oct 12"
String formatMonthDay(DateTime d) => '${_shortMonths[d.month - 1]} ${d.day}';

/// "Due today 18:00" / "Due Fri 23:59" (within a week) / "Due Nov 14 18:00" /
/// "Overdue"
String formatDueLabel(DateTime due, DateTime now) {
  if (!due.isAfter(now)) return 'Overdue';
  final days = daysUntil(due, now);
  final day = days == 0
      ? 'today'
      : days < 7
          ? _shortWeekdays[due.weekday - 1]
          : formatMonthDay(due);
  return 'Due $day ${formatHm(due)}';
}

/// Quiz countdown split so the UI can highlight the time:
/// "Next quiz in **4 days**", "Next quiz **tomorrow**", "Next quiz **today**".
({String lead, String highlight}) quizCountdown(DateTime date, DateTime now) {
  final days = daysUntil(date, now);
  if (days <= 0) return (lead: '', highlight: 'today');
  if (days == 1) return (lead: '', highlight: 'tomorrow');
  return (lead: 'in ', highlight: '$days days');
}

String paceLabel(CoursePace pace) => switch (pace) {
      CoursePace.ahead => 'Completed ahead of schedule',
      CoursePace.onTrack => 'Right on schedule',
      CoursePace.behind => 'Behind schedule, time to catch up',
    };

/// "24 classmates online right now"
String classmatesOnlineLabel(int count) => count <= 0
    ? 'No classmates online right now'
    : '$count classmate${count == 1 ? '' : 's'} online right now';

/// "3 files"
String filesCountLabel(int count) => '$count file${count == 1 ? '' : 's'}';

/// Form validator for the lab repository link.
String? validateRepoUrl(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Paste your repository link';
  return isValidRepoUrl(v) ? null : 'Enter a valid https:// repository link';
}
