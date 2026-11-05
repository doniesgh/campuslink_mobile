import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/mock_timetable_repository.dart';
import '../../domain/entities/class_session.dart';
import '../../domain/entities/timetable_week.dart';
import '../../domain/repositories/timetable_repository.dart';

/// Swap MockTimetableRepository for the Dio-based implementation when the API is ready.
final timetableRepositoryProvider =
    Provider<TimetableRepository>((ref) => MockTimetableRepository());

final todayTimetableProvider = FutureProvider.autoDispose<TimetableDay>(
  (ref) async =>
      (await ref.watch(timetableRepositoryProvider).getDay(DateTime.now())).unwrap(),
);

/// The week starting on the given Monday (at midnight, see `weekStart`).
final timetableWeekProvider = FutureProvider.autoDispose.family<TimetableWeek, DateTime>(
  (ref, monday) async =>
      (await ref.watch(timetableRepositoryProvider).getWeek(monday)).unwrap(),
);
