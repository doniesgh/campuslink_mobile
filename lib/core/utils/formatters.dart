/// 1420 -> "1,420"
String formatThousands(num value) => value
    .round()
    .toString()
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

/// "13:15" (or "13h15" with sep: 'h')
String formatHm(DateTime d, {String sep = ':'}) =>
    '${d.hour.toString().padLeft(2, '0')}$sep${d.minute.toString().padLeft(2, '0')}';

int _dayDiff(DateTime d, DateTime now) =>
    DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;

/// "Today" / "Tomorrow" / "05/11"
String formatDayCaption(DateTime d, {DateTime? now}) {
  final diff = _dayDiff(d, now ?? DateTime.now());
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// "Monday, 19 May"
String formatLongDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';

/// "10:15 – 12:15"
String formatTimeRange(DateTime start, DateTime end) =>
    '${formatHm(start)} – ${formatHm(end)}';

/// "Good morning" / "Good afternoon" / "Good evening"
String formatGreeting(DateTime now) => now.hour < 12
    ? 'Good morning'
    : now.hour < 18
        ? 'Good afternoon'
        : 'Good evening';

/// "18 min" / "1h 05" (negative durations count as zero)
String formatShortDuration(Duration d) {
  final minutes = d.isNegative ? 0 : (d.inSeconds / 60).ceil();
  if (minutes < 60) return '$minutes min';
  return '${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}';
}

/// "just now" / "12 min ago" / "2h ago" / "3d ago" / "05/11"
String formatTimeAgo(DateTime d, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(d);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

/// "Aujourd'hui · 13h15" / "Demain · 08h00" (French, as in the ride cards of the mockup)
String formatDepartureLabel(DateTime d, {DateTime? now}) {
  final diff = _dayDiff(d, now ?? DateTime.now());
  final day = diff == 0
      ? "Aujourd'hui"
      : diff == 1
          ? 'Demain'
          : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  return '$day · ${formatHm(d, sep: 'h')}';
}
