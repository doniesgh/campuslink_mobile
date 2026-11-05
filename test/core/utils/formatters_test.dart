import 'package:campuspulse/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatLongDate', () {
    expect(formatLongDate(DateTime(2026, 5, 18)), 'Monday, 18 May');
    expect(formatLongDate(DateTime(2026, 11, 5)), 'Thursday, 5 November');
  });

  test('formatTimeRange', () {
    expect(
      formatTimeRange(DateTime(2026, 1, 1, 8, 5), DateTime(2026, 1, 1, 10, 0)),
      '08:05 – 10:00',
    );
  });

  test('formatGreeting follows the time of day', () {
    expect(formatGreeting(DateTime(2026, 1, 1, 9)), 'Good morning');
    expect(formatGreeting(DateTime(2026, 1, 1, 12)), 'Good afternoon');
    expect(formatGreeting(DateTime(2026, 1, 1, 18)), 'Good evening');
  });

  test('formatShortDuration rounds up to the minute', () {
    expect(formatShortDuration(const Duration(minutes: 18)), '18 min');
    expect(formatShortDuration(const Duration(seconds: 30)), '1 min');
    expect(formatShortDuration(const Duration(minutes: 65)), '1h 05');
    expect(formatShortDuration(const Duration(minutes: -5)), '0 min');
  });

  test('formatTimeAgo', () {
    final now = DateTime(2026, 1, 1, 12);
    expect(formatTimeAgo(now.subtract(const Duration(seconds: 30)), now: now), 'just now');
    expect(formatTimeAgo(now.subtract(const Duration(minutes: 12)), now: now), '12 min ago');
    expect(formatTimeAgo(now.subtract(const Duration(hours: 2)), now: now), '2h ago');
    expect(formatTimeAgo(now.subtract(const Duration(days: 3)), now: now), '3d ago');
    expect(formatTimeAgo(DateTime(2025, 12, 22), now: now), '22/12');
  });
}
