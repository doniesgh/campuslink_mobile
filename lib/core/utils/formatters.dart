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
