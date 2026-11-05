import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current time, refreshed every 30 seconds so countdowns ("in 18 min") stay
/// accurate. Override it in tests to freeze time.
///
/// Read it as `ref.watch(clockProvider).valueOrNull ?? DateTime.now()`.
final clockProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 30), (_) => DateTime.now());
});
