import '../../../../core/error/result.dart';
import '../entities/new_ride.dart';
import '../entities/ride.dart';

abstract interface class CarpoolRepository {
  Future<Result<List<Ride>>> getRides();
  Future<Result<Ride>> getRide(String id);
  Future<Result<void>> reserveSeats({required String rideId, required List<String> seatIds});

  /// Publishes [ride] with the signed-in student as its driver, and returns
  /// it as every student now sees it in [getRides].
  Future<Result<Ride>> createRide(NewRide ride);

  /// Deletes the student's own ride [id]. Returns a ServerFailure if the
  /// ride is not found or the student is not its driver.
  Future<Result<void>> deleteRide(String id);
}
