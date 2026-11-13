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

  /// The driver edits their ride ([rideId] must be one they published).
  /// Booked seats are kept; the seat count can't go below them.
  Future<Result<Ride>> updateRide(String rideId, NewRide ride);

  /// The driver deletes their ride, with its bookings.
  Future<Result<void>> deleteRide(String rideId);

  /// The driver cancels the booking of [seatId]: the seat is free again.
  Future<Result<Ride>> cancelReservation({required String rideId, required String seatId});
}
