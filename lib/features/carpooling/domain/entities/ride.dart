enum SeatStatus { driver, booked, free }

enum RideAmenity { nonSmoking, airConditioned, musicOk }

class Seat {
  const Seat({required this.id, required this.label, required this.status});

  final String id;

  /// Driver / passenger name, or "Seat #3" for a free seat.
  final String label;
  final SeatStatus status;
}

class Driver {
  const Driver({
    required this.name,
    required this.rating,
    required this.profile,
    required this.ridesCompleted,
    required this.carModel,
    required this.carColor,
    required this.plate,
    this.isCarVerified = false,
  });

  final String name;
  final double rating;

  /// e.g. "4th Year Telecom Engineering student"
  final String profile;
  final int ridesCompleted;
  final String carModel;
  final String carColor;
  final String plate;
  final bool isCarVerified;
}

class Ride {
  const Ride({
    required this.id,
    required this.code,
    required this.pickup,
    required this.dropoff,
    required this.pickupTag,
    required this.dropoffTag,
    required this.dropoffNote,
    required this.departure,
    required this.arrival,
    required this.distanceKm,
    required this.pricePerSeat,
    required this.driver,
    required this.seats,
    this.amenities = const [],
  });

  final String id;
  final String code;
  final String pickup;
  final String dropoff;
  final String pickupTag;
  final String dropoffTag;
  final String dropoffNote;
  final DateTime departure;
  final DateTime arrival;
  final double distanceKm;
  final double pricePerSeat;
  final Driver driver;
  final List<Seat> seats;
  final List<RideAmenity> amenities;

  List<Seat> get freeSeats => seats.where((s) => s.status == SeatStatus.free).toList();
  int get freeSeatCount => freeSeats.length;
  bool get isAlmostFull => freeSeatCount == 1;
  Duration get duration => arrival.difference(departure);

  double totalFor(int seatCount) => pricePerSeat * seatCount;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return pickup.toLowerCase().contains(q) ||
        dropoff.toLowerCase().contains(q) ||
        driver.name.toLowerCase().contains(q);
  }

  Ride copyWithSeats(List<Seat> newSeats) => Ride(
        id: id,
        code: code,
        pickup: pickup,
        dropoff: dropoff,
        pickupTag: pickupTag,
        dropoffTag: dropoffTag,
        dropoffNote: dropoffNote,
        departure: departure,
        arrival: arrival,
        distanceKm: distanceKm,
        pricePerSeat: pricePerSeat,
        driver: driver,
        seats: newSeats,
        amenities: amenities,
      );
}
