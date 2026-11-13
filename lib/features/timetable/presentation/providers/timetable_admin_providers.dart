import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/repositories/mock_timetable_admin_repository.dart';
import '../../data/repositories/timetable_admin_repository_impl.dart';
import '../../domain/entities/timetable_slot.dart';
import '../../domain/repositories/timetable_admin_repository.dart';
import 'timetable_providers.dart';

/// The admin timetable API, or the in-memory fake on the demo store.
final timetableAdminRepositoryProvider = Provider<TimetableAdminRepository>((ref) {
  return Env.useMock
      ? MockTimetableAdminRepository(store: ref.watch(mockTimetableStoreProvider))
      : TimetableAdminRepositoryImpl(ref.watch(dioProvider));
});

/// Every class of the week (Administration › Timetable).
final adminTimetableSlotsProvider = FutureProvider.autoDispose<List<TimetableSlot>>(
  (ref) async => (await ref.watch(timetableAdminRepositoryProvider).getSlots()).unwrap(),
);
