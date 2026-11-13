import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/new_ride.dart';
import '../../domain/entities/ride.dart';
import '../../domain/new_ride_rules.dart';
import '../../domain/repositories/carpool_repository.dart';

/// In-memory fake used with USE_MOCK=true (no backend needed). Published
/// rides live until the app restarts and follow the server's rules.
class MockCarpoolRepository implements CarpoolRepository {
  /// [driverName] names the signed-in student on the rides they publish.
  MockCarpoolRepository({
    Duration latency = const Duration(milliseconds: 500),
    String Function()? driverName,
    DateTime Function()? clock,
  })  : _latency = latency,
        _driverName = driverName ?? (() => 'You'),
        _clock = clock ?? DateTime.now,
        _rides = _seed();

  final List<Ride> _rides;
  final Duration _latency;
  final String Function() _driverName;
  final DateTime Function() _clock;

  /// Published rides are numbered after the demo ones, like on the server.
  int _lastRideNumber = 4093;

  static const _ownRide = "You can't book a seat in your own ride.";
  static const _notYourRide = 'Only the driver can change this ride.';

  static List<Ride> _seed() {
    final now = DateTime.now();
    DateTime at(int dayOffset, int h, int m) =>
        DateTime(now.year, now.month, now.day + dayOffset, h, m);

    return [
      Ride(
        id: 'es-4091',
        code: 'ES-4091',
        pickup: 'Tunis Centre (Passage)',
        dropoff: 'ESPRIT Ghazela (Bloc H)',
        pickupTag: 'Passage',
        dropoffTag: 'ESPRIT Bloc H',
        dropoffNote: 'Drop-off direct at Bloc H (Ghazela Technopark)',
        departure: at(0, 13, 15),
        arrival: at(0, 13, 45),
        distanceKm: 14.2,
        pricePerSeat: 2.5,
        driver: const Driver(
          name: 'Sarra K.',
          rating: 4.9,
          profile: '4th Year Telecom Engineering student',
          ridesCompleted: 38,
          carModel: 'Renault Clio 4',
          carColor: 'White',
          plate: '218 · TN · 9812',
          isCarVerified: true,
        ),
        seats: const [
          Seat(id: 's1', label: 'Sarra K.', status: SeatStatus.driver),
          Seat(id: 's2', label: 'Ahmed D.', status: SeatStatus.booked),
          Seat(id: 's3', label: 'Seat #3', status: SeatStatus.free),
          Seat(id: 's4', label: 'Seat #4', status: SeatStatus.free),
        ],
        amenities: const [
          RideAmenity.nonSmoking,
          RideAmenity.airConditioned,
          RideAmenity.musicOk,
        ],
      ),
      Ride(
        id: 'es-4092',
        code: 'ES-4092',
        pickup: 'Ariana Ville (Station Métro 2)',
        dropoff: 'ESPRIT Charguia 2',
        pickupTag: 'Métro 2',
        dropoffTag: 'ESPRIT Charguia',
        dropoffNote: 'Drop-off at the main entrance',
        departure: at(1, 8, 0),
        arrival: at(1, 8, 25),
        distanceKm: 9.6,
        pricePerSeat: 2.0,
        driver: const Driver(
          name: 'Youssef M.',
          rating: 4.8,
          profile: '3rd Year Computer Science student',
          ridesCompleted: 21,
          carModel: 'Peugeot 208',
          carColor: 'Grey',
          plate: '195 · TN · 4410',
          isCarVerified: true,
        ),
        seats: const [
          Seat(id: 's1', label: 'Youssef M.', status: SeatStatus.driver),
          Seat(id: 's2', label: 'Seat #2', status: SeatStatus.free),
          Seat(id: 's3', label: 'Seat #3', status: SeatStatus.free),
          Seat(id: 's4', label: 'Seat #4', status: SeatStatus.free),
        ],
        amenities: const [RideAmenity.nonSmoking, RideAmenity.airConditioned],
      ),
      Ride(
        id: 'es-4093',
        code: 'ES-4093',
        pickup: 'ESPRIT Ghazela',
        dropoff: 'La Marsa / Gammarth',
        pickupTag: 'ESPRIT Ghazela',
        dropoffTag: 'La Marsa',
        dropoffNote: 'Drop-off at La Marsa Corniche',
        departure: at(0, 17, 30),
        arrival: at(0, 18, 5),
        distanceKm: 18.4,
        pricePerSeat: 3.0,
        driver: const Driver(
          name: 'Kenza B.',
          rating: 5.0,
          profile: '5th Year Software Engineering student',
          ridesCompleted: 54,
          carModel: 'Kia Picanto',
          carColor: 'Red',
          plate: '207 · TN · 7731',
          isCarVerified: true,
        ),
        seats: const [
          Seat(id: 's1', label: 'Kenza B.', status: SeatStatus.driver),
          Seat(id: 's2', label: 'Rami T.', status: SeatStatus.booked),
          Seat(id: 's3', label: 'Lina S.', status: SeatStatus.booked),
          Seat(id: 's4', label: 'Seat #4', status: SeatStatus.free),
        ],
        amenities: const [RideAmenity.airConditioned, RideAmenity.musicOk],
      ),
    ];
  }

  @override
  Future<Result<List<Ride>>> getRides() async {
    await Future<void>.delayed(_latency);
    return Success(List<Ride>.unmodifiable(_rides));
  }

  @override
  Future<Result<Ride>> getRide(String id) async {
    await Future<void>.delayed(_latency);
    final index = _rides.indexWhere((r) => r.id == id);
    if (index < 0) return const Err(ServerFailure('Ride not found.'));
    return Success(_rides[index]);
  }

  @override
  Future<Result<void>> reserveSeats({
    required String rideId,
    required List<String> seatIds,
  }) async {
    await Future<void>.delayed(_latency);
    final index = _rides.indexWhere((r) => r.id == rideId);
    if (index < 0) return const Err(ServerFailure('Ride not found.'));

    final ride = _rides[index];
    if (ride.isMine) return const Err(ServerFailure(_ownRide));
    final free = ride.freeSeats.map((s) => s.id).toSet();
    if (seatIds.isEmpty || !seatIds.every(free.contains)) {
      return const Err(ValidationFailure('This seat is no longer available.'));
    }
    _rides[index] = ride.copyWithSeats([
      for (final s in ride.seats)
        seatIds.contains(s.id)
            ? Seat(id: s.id, label: 'You', status: SeatStatus.booked)
            : s,
    ]);
    return const Success(null);
  }


  /// Like the server: the student drives (seat "s1", with their name), as a
  /// new driver (no rating yet) whose car isn't verified.
  @override
  Future<Result<Ride>> createRide(NewRide ride) async {
    await Future<void>.delayed(_latency);
    final errors = validateNewRide(ride, now: _clock());
    if (errors.isNotEmpty) return Err(ValidationFailure(errors.values.first));

    final number = ++_lastRideNumber;
    final name = _driverName();
    final note = ride.dropoffNote.trim();
    final created = Ride(
      id: 'es-$number',
      code: 'ES-$number',
      pickup: ride.pickup.trim(),
      dropoff: ride.dropoff.trim(),
      pickupTag: ride.pickupTag.trim(),
      dropoffTag: ride.dropoffTag.trim(),
      dropoffNote: note,
      departure: ride.departure,
      arrival: ride.arrival,
      distanceKm: ride.distanceKm ?? 0,
      pricePerSeat: ride.pricePerSeat,
      driver: Driver(
        name: name,
        rating: 0,
        profile: 'ESPRIT student',
        ridesCompleted: 0,
        carModel: ride.carModel.trim(),
        carColor: ride.carColor.trim(),
        plate: ride.plate.trim(),
      ),
      seats: [
        Seat(id: 's1', label: name, status: SeatStatus.driver),
        for (var i = 2; i <= ride.seatCount + 1; i++)
          Seat(id: 's$i', label: 'Seat #$i', status: SeatStatus.free),
      ],
      amenities: ride.amenities.toSet().toList(),
      isMine: true,
    );
    _rides.add(created);
    return Success(created);
  }

  /// Like the server: booked seats are kept, free seats follow the new count.
  @override
  Future<Result<Ride>> updateRide(String rideId, NewRide ride) async {
    await Future<void>.delayed(_latency);
    final index = _rides.indexWhere((r) => r.id == rideId);
    if (index < 0) return const Err(ServerFailure('Ride not found.'));
    final old = _rides[index];
    if (!old.isMine) return const Err(ServerFailure(_notYourRide));

    final errors = validateNewRide(ride, now: _clock());
    if (errors.isNotEmpty) return Err(ValidationFailure(errors.values.first));

    final booked = old.seats.where((s) => s.status == SeatStatus.booked).length;
    if (ride.seatCount < booked) {
      return Err(ValidationFailure(
        '$booked ${booked == 1 ? 'place est déjà réservée' : 'places sont déjà réservées'} : '
        'annulez des réservations avant de réduire le nombre de places.',
      ));
    }

    final seats = [...old.seats];
    final wanted = ride.seatCount + 1;
    while (seats.length > wanted) {
      seats.removeAt(seats.lastIndexWhere((s) => s.status == SeatStatus.free));
    }
    var next = seats.fold<int>(0, (m, s) {
          final n = int.tryParse(s.id.substring(1)) ?? 0;
          return n > m ? n : m;
        }) +
        1;
    while (seats.length < wanted) {
      seats.add(Seat(id: 's$next', label: 'Seat #$next', status: SeatStatus.free));
      next++;
    }
    // Free seats are labelled by their position, like the server does.
    for (var i = 0; i < seats.length; i++) {
      if (seats[i].status == SeatStatus.free) {
        seats[i] = Seat(id: seats[i].id, label: 'Seat #${i + 1}', status: SeatStatus.free);
      }
    }

    final note = ride.dropoffNote.trim();
    final updated = Ride(
      id: old.id,
      code: old.code,
      pickup: ride.pickup.trim(),
      dropoff: ride.dropoff.trim(),
      pickupTag: ride.pickupTag.trim(),
      dropoffTag: ride.dropoffTag.trim(),
      dropoffNote: note,
      departure: ride.departure,
      arrival: ride.arrival,
      distanceKm: ride.distanceKm ?? 0,
      pricePerSeat: ride.pricePerSeat,
      driver: Driver(
        name: old.driver.name,
        rating: old.driver.rating,
        profile: old.driver.profile,
        ridesCompleted: old.driver.ridesCompleted,
        carModel: ride.carModel.trim(),
        carColor: ride.carColor.trim(),
        plate: ride.plate.trim(),
        isCarVerified: old.driver.isCarVerified,
      ),
      seats: seats,
      amenities: ride.amenities.toSet().toList(),
      isMine: true,
    );
    _rides[index] = updated;
    return Success(updated);
  }

  @override
  Future<Result<void>> deleteRide(String rideId) async {
    await Future<void>.delayed(_latency);
    final index = _rides.indexWhere((r) => r.id == rideId);
    if (index < 0) return const Err(ServerFailure('Ride not found.'));
    if (!_rides[index].isMine) return const Err(ServerFailure(_notYourRide));
    _rides.removeAt(index);
    return const Success(null);
  }

  @override
  Future<Result<Ride>> cancelReservation({required String rideId, required String seatId}) async {
    await Future<void>.delayed(_latency);
    final index = _rides.indexWhere((r) => r.id == rideId);
    if (index < 0) return const Err(ServerFailure('Ride not found.'));
    final ride = _rides[index];
    if (!ride.isMine) return const Err(ServerFailure(_notYourRide));
    final i = ride.seats.indexWhere((s) => s.id == seatId && s.status == SeatStatus.booked);
    if (i < 0) return const Err(ValidationFailure('This seat is not booked.'));

    final seats = [...ride.seats];
    seats[i] = Seat(id: seatId, label: 'Seat #${i + 1}', status: SeatStatus.free);
    final updated = ride.copyWithSeats(seats);
    _rides[index] = updated;
    return Success(updated);
  }
}
