import 'package:campuspulse/core/error/failures.dart';
import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/features/carpooling/data/repositories/mock_carpool_repository.dart';
import 'package:campuspulse/features/carpooling/domain/entities/new_ride.dart';
import 'package:campuspulse/features/carpooling/domain/entities/ride.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 6, 10);

MockCarpoolRepository _repo() => MockCarpoolRepository(
      latency: Duration.zero,
      driverName: () => 'Dony Mansour',
      clock: () => _now,
    );

NewRide _newRide({int seatCount = 2, DateTime? departure, String note = ' '}) {
  final leaves = departure ?? DateTime(2026, 11, 7, 8, 30);
  return NewRide(
    pickup: ' Lac 2 (Tunis City) ',
    pickupTag: 'Lac 2',
    dropoff: 'ESPRIT Ghazela (Bloc E)',
    dropoffTag: 'ESPRIT Bloc E',
    departure: leaves,
    arrival: leaves.add(const Duration(minutes: 35)),
    seatCount: seatCount,
    pricePerSeat: 0,
    carModel: 'Volkswagen Polo',
    carColor: 'Blue',
    plate: '231 TN 1187',
    amenities: const [RideAmenity.musicOk, RideAmenity.musicOk],
    dropoffNote: note,
  );
}

Failure _failureOf(Result<Object?> r) =>
    r.when(success: (_) => fail('expected a failure'), failure: (f) => f);

void main() {
  test('getRides starts with the three demo rides, none of them the student\'s', () async {
    final rides = (await _repo().getRides()).unwrap();
    expect(rides.map((r) => r.id), ['es-4091', 'es-4092', 'es-4093']);
    expect(rides.where((r) => r.isMine), isEmpty);
  });

  test('createRide publishes the ride like the server does', () async {
    final repo = _repo();

    final ride = (await repo.createRide(_newRide())).unwrap();

    expect(ride.id, 'es-4094');
    expect(ride.code, 'ES-4094');
    expect(ride.pickup, 'Lac 2 (Tunis City)');
    expect(ride.dropoffNote, '');
    expect(ride.hasDistance, isFalse);
    expect(ride.pricePerSeat, 0);
    expect(ride.amenities, [RideAmenity.musicOk]);
    expect(ride.isMine, isTrue);
    expect(ride.driver.name, 'Dony Mansour');
    expect(ride.driver.isNewDriver, isTrue);
    expect(ride.driver.isCarVerified, isFalse);
    expect(
      [for (final s in ride.seats) (s.id, s.label, s.status)],
      [
        ('s1', 'Dony Mansour', SeatStatus.driver),
        ('s2', 'Seat #2', SeatStatus.free),
        ('s3', 'Seat #3', SeatStatus.free),
      ],
    );

    final rides = (await repo.getRides()).unwrap();
    expect(rides.map((r) => r.id), contains('es-4094'));
    expect((await repo.getRide('es-4094')).unwrap().code, 'ES-4094');

    final next = (await repo.createRide(_newRide(seatCount: 4))).unwrap();
    expect(next.id, 'es-4095');
    expect(next.seats, hasLength(5));
  });

  test('createRide refuses a ride the server would refuse, with its message', () async {
    final repo = _repo();

    final past = _failureOf(await repo.createRide(_newRide(departure: _now)));
    expect(past, isA<ValidationFailure>());
    expect(past.message, 'Le départ doit être dans le futur.');

    final seats = _failureOf(await repo.createRide(_newRide(seatCount: 5)));
    expect(seats.message, 'Proposez entre 1 et 4 places.');

    expect((await repo.getRides()).unwrap(), hasLength(3));
  });

  test("the driver can't book a seat in their own ride, others still can", () async {
    final repo = _repo();
    final ride = (await repo.createRide(_newRide())).unwrap();

    final own = _failureOf(await repo.reserveSeats(rideId: ride.id, seatIds: ['s2']));
    expect(own.message, "You can't book a seat in your own ride.");

    expect(await repo.reserveSeats(rideId: 'es-4092', seatIds: ['s2']), isA<Success<void>>());
  });
}
