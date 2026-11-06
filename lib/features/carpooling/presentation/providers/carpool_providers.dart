import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/repositories/carpool_repository_impl.dart';
import '../../data/repositories/mock_carpool_repository.dart';
import '../../domain/entities/carpool_impact.dart';
import '../../domain/entities/ride.dart';
import '../../domain/repositories/carpool_repository.dart';

/// Mock data with USE_MOCK=true, the Node.js API otherwise.
final carpoolRepositoryProvider = Provider<CarpoolRepository>((ref) {
  return Env.useMock
      ? MockCarpoolRepository()
      : CarpoolRepositoryImpl(ref.watch(dioProvider));
});

final ridesProvider = FutureProvider.autoDispose<List<Ride>>(
  (ref) async => (await ref.watch(carpoolRepositoryProvider).getRides()).unwrap(),
);

final rideDetailProvider = FutureProvider.autoDispose.family<Ride, String>(
  (ref, id) async => (await ref.watch(carpoolRepositoryProvider).getRide(id)).unwrap(),
);

final impactProvider = FutureProvider.autoDispose<CarpoolImpact>(
  (ref) async => (await ref.watch(carpoolRepositoryProvider).getMonthlyImpact()).unwrap(),
);
