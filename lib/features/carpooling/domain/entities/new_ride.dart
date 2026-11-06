import 'ride.dart';

/// A ride the signed-in student offers as its driver ("Proposer un trajet"),
/// before it is published. Publishing returns the full [Ride]: its id, the
/// driver (the student) and the seats.
///
/// Check it with `validateNewRide` (new_ride_rules.dart) before sending.
class NewRide {
  const NewRide({
    required this.pickup,
    required this.pickupTag,
    required this.dropoff,
    required this.dropoffTag,
    required this.departure,
    required this.arrival,
    required this.seatCount,
    required this.pricePerSeat,
    required this.carModel,
    required this.carColor,
    required this.plate,
    this.amenities = const [],
    this.dropoffNote = '',
    this.distanceKm,
  });

  /// e.g. "Tunis Centre (Passage)"
  final String pickup;

  /// Short form shown on the route map, e.g. "Passage".
  final String pickupTag;
  final String dropoff;
  final String dropoffTag;
  final DateTime departure;
  final DateTime arrival;

  /// Passenger seats offered (1 to 4). The driver's seat is not counted.
  final int seatCount;

  /// In TND. 0 means free.
  final double pricePerSeat;
  final String carModel;
  final String carColor;
  final String plate;
  final List<RideAmenity> amenities;

  /// Optional: blank when the driver has nothing to add.
  final String dropoffNote;

  /// Optional.
  final double? distanceKm;
}
