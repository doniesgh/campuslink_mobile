import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/mock_carpool_repository.dart';
import '../../domain/entities/carpool_impact.dart';
import '../../domain/entities/ride.dart';
import '../../domain/repositories/carpool_repository.dart';

/// Swap MockCarpoolRepository for the Dio-based implementation when the API is ready.
final carpoolRepositoryProvider =
    Provider<CarpoolRepository>((ref) => MockCarpoolRepository());

final ridesProvider = FutureProvider.autoDispose<List<Ride>>(
  (ref) async => (await ref.watch(carpoolRepositoryProvider).getRides()).unwrap(),
);

final rideDetailProvider = FutureProvider.autoDispose.family<Ride, String>(
  (ref, id) async => (await ref.watch(carpoolRepositoryProvider).getRide(id)).unwrap(),
);

final impactProvider = FutureProvider.autoDispose<CarpoolImpact>(
  (ref) async => (await ref.watch(carpoolRepositoryProvider).getMonthlyImpact()).unwrap(),
);
