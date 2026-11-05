import '../../../../core/error/result.dart';
import '../entities/carpool_impact.dart';
import '../entities/ride.dart';

abstract interface class CarpoolRepository {
  Future<Result<List<Ride>>> getRides();
  Future<Result<Ride>> getRide(String id);
  Future<Result<void>> reserveSeats({required String rideId, required List<String> seatIds});
  Future<Result<CarpoolImpact>> getMonthlyImpact();
}
