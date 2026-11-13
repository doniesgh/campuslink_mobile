import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/repositories/mock_timetable_repository.dart';
import '../../data/repositories/mock_timetable_store.dart';
import '../../data/repositories/timetable_repository_impl.dart';
import '../../domain/entities/class_session.dart';
import '../../domain/entities/timetable_week.dart';
import '../../domain/repositories/timetable_repository.dart';

/// The weekly classes of the demo mode (USE_MOCK=true), shared by the student
/// screens and the admin screens, so an admin's change shows everywhere.
final mockTimetableStoreProvider = Provider<MockTimetableStore>((ref) => MockTimetableStore());

/// The API (USE_MOCK=false) or the in-memory fake.
final timetableRepositoryProvider = Provider<TimetableRepository>((ref) {
  return Env.useMock
      ? MockTimetableRepository(store: ref.watch(mockTimetableStoreProvider))
      : TimetableRepositoryImpl(ref.watch(dioProvider));
});

final todayTimetableProvider = FutureProvider.autoDispose<TimetableDay>(
  (ref) async =>
      (await ref.watch(timetableRepositoryProvider).getDay(DateTime.now())).unwrap(),
);

/// The week starting on the given Monday (at midnight, see `weekStart`).
final timetableWeekProvider = FutureProvider.autoDispose.family<TimetableWeek, DateTime>(
  (ref, monday) async =>
      (await ref.watch(timetableRepositoryProvider).getWeek(monday)).unwrap(),
);
