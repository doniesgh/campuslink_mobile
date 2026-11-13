import '../../../../core/error/result.dart';
import '../entities/new_ride.dart';
import '../entities/ride.dart';

abstract interface class CarpoolRepository {
  Future<Result<List<Ride>>> getRides();
  Future<Result<Ride>> getRide(String id);

  /// Books [seatIds]. On a ride published by a student the seats are only
  /// requested ([SeatStatus.pending]) until the driver accepts; on a demo
  /// ride they are booked at once. Returns the ride as the student now sees it.
  Future<Result<Ride>> reserveSeats({required String rideId, required List<String> seatIds});

  /// The rides where the signed-in student booked or asked for a seat.
  Future<Result<List<Ride>>> getMyBookings();

  /// The upcoming rides the signed-in student drives that have passengers:
  /// seats asked for ([SeatStatus.pending]) or confirmed ([SeatStatus.booked]).
  Future<Result<List<Ride>>> getMyRideRequests();

  /// Publishes [ride] with the signed-in student as its driver, and returns
  /// it as every student now sees it in [getRides].
  Future<Result<Ride>> createRide(NewRide ride);

  /// The driver edits their ride ([rideId] must be one they published).
  /// Booked seats are kept; the seat count can't go below them.
  Future<Result<Ride>> updateRide(String rideId, NewRide ride);

  /// The driver deletes their ride, with its bookings.
  Future<Result<void>> deleteRide(String rideId);

  /// Cancels the booking (or pending request) of [seatId]: the seat is free
  /// again. Allowed to the driver and to the student who booked it.
  Future<Result<Ride>> cancelReservation({required String rideId, required String seatId});

  /// The driver accepts a pending request: the seat becomes booked.
  Future<Result<Ride>> acceptReservation({required String rideId, required String seatId});

  /// The driver refuses a pending request: the seat is free again.
  Future<Result<Ride>> refuseReservation({required String rideId, required String seatId});
}
