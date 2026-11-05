import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/carpool_impact.dart';
import '../../domain/entities/ride.dart';
import '../../domain/repositories/carpool_repository.dart';

/// In-memory fake used until the Node.js API exists.
/// Later: add `CarpoolRepositoryImpl` (Dio) and swap it in carpool_providers.dart.
class MockCarpoolRepository implements CarpoolRepository {
  MockCarpoolRepository() : _rides = _seed();

  final List<Ride> _rides;
  static const _latency = Duration(milliseconds: 500);

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

  @override
  Future<Result<CarpoolImpact>> getMonthlyImpact() async {
    await Future<void>.delayed(_latency);
    return const Success(CarpoolImpact(savedKg: 1420, goalKg: 2000));
  }
}
