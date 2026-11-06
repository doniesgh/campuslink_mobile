import 'dart:convert';

import 'package:campuspulse/features/carpooling/data/models/carpool_models.dart';
import 'package:campuspulse/features/carpooling/domain/entities/new_ride.dart';
import 'package:campuspulse/features/carpooling/domain/entities/ride.dart';
import 'package:flutter_test/flutter_test.dart';

import 'carpool_fixtures.dart';

Map<String, dynamic> _decode(String s) => jsonDecode(s) as Map<String, dynamic>;

void main() {
  group('RideModel.fromJson (backend fixture)', () {
    final ride = RideModel.fromJson(_decode(rideJson));

    test('reads the ride fields', () {
      expect(ride.id, 'es-4092');
      expect(ride.code, 'ES-4092');
      expect(ride.pickup, 'Ariana Ville (Station Métro 2)');
      expect(ride.dropoff, 'ESPRIT Charguia 2');
      expect(ride.pickupTag, 'Métro 2');
      expect(ride.dropoffTag, 'ESPRIT Charguia');
      expect(ride.dropoffNote, 'Drop-off at the main entrance');
      expect(ride.distanceKm, 9.6);
      // Sent as the integer 2.
      expect(ride.pricePerSeat, 2.0);
      expect(ride.amenities, [RideAmenity.nonSmoking, RideAmenity.airConditioned]);
    });

    test('turns the UTC instants into local times', () {
      expect(ride.departure.isUtc, isFalse);
      expect(ride.departure.isAtSameMomentAs(DateTime.utc(2026, 11, 7, 7)), isTrue);
      expect(ride.arrival.isAtSameMomentAs(DateTime.utc(2026, 11, 7, 7, 25)), isTrue);
      expect(ride.duration, const Duration(minutes: 25));
    });

    test('reads the driver', () {
      final d = ride.driver;
      expect(d.name, 'Youssef M.');
      expect(d.rating, 4.8);
      expect(d.profile, '3rd Year Computer Science student');
      expect(d.ridesCompleted, 21);
      expect(d.carModel, 'Peugeot 208');
      expect(d.carColor, 'Grey');
      expect(d.plate, '195 · TN · 4410');
      expect(d.isCarVerified, isTrue);
    });

    test('reads the seats with their ready-to-show labels', () {
      expect(
        [for (final s in ride.seats) (s.id, s.label, s.status)],
        [
          ('s1', 'Youssef M.', SeatStatus.driver),
          ('s2', 'Sarra Kefi', SeatStatus.booked),
          ('s3', 'You', SeatStatus.booked),
          ('s4', 'Seat #4', SeatStatus.free),
        ],
      );
      expect(ride.freeSeatCount, 1);
      expect(ride.isAlmostFull, isTrue);
    });

    test("is not the student's own ride, and its driver is rated", () {
      expect(ride.isMine, isFalse);
      expect(ride.driver.isNewDriver, isFalse);
      expect(ride.hasDistance, isTrue);
    });
  });

  group('RideModel.fromJson (ride a student just published)', () {
    final ride = RideModel.fromJson(_decode(createdRideJson));

    test('reads the ride as every student sees it', () {
      expect(ride.id, 'es-4094');
      expect(ride.code, 'ES-4094');
      expect(ride.pickup, 'Lac 2 (Tunis City)');
      expect(ride.pickupTag, 'Lac 2');
      expect(ride.dropoff, 'ESPRIT Ghazela (Bloc E)');
      expect(ride.dropoffTag, 'ESPRIT Bloc E');
      expect(ride.departure.isAtSameMomentAs(DateTime.utc(2026, 11, 7, 7, 30)), isTrue);
      expect(ride.duration, const Duration(minutes: 35));
      expect(ride.pricePerSeat, 2.5);
      expect(ride.amenities, [RideAmenity.nonSmoking, RideAmenity.musicOk]);
    });

    test('has no note and no distance (sent as "" and the integer 0)', () {
      expect(ride.dropoffNote, '');
      expect(ride.distanceKm, 0.0);
      expect(ride.hasDistance, isFalse);
    });

    test('belongs to the student, a new driver with an unverified car', () {
      expect(ride.isMine, isTrue);
      final d = ride.driver;
      expect(d.name, 'Dony Mansour');
      expect(d.profile, '4th Year Software Engineering student');
      // Sent as the integer 0: no rating system yet.
      expect(d.rating, 0.0);
      expect(d.ridesCompleted, 0);
      expect(d.isNewDriver, isTrue);
      expect(d.isCarVerified, isFalse);
      expect((d.carModel, d.carColor, d.plate), ('Volkswagen Polo', 'Blue', '231 TN 1187'));
    });

    test('has the driver seat and free passenger seats', () {
      expect(
        [for (final s in ride.seats) (s.id, s.label, s.status)],
        [
          ('s1', 'Dony Mansour', SeatStatus.driver),
          ('s2', 'Seat #2', SeatStatus.free),
          ('s3', 'Seat #3', SeatStatus.free),
          ('s4', 'Seat #4', SeatStatus.free),
        ],
      );
      expect(ride.freeSeatCount, 3);
    });

    test('keeps isMine when the seats change', () {
      expect(ride.copyWithSeats(ride.seats).isMine, isTrue);
    });
  });

  test('RideModel reads a ride without "isMine" (older server) as not mine', () {
    final json = _decode(rideJson)..remove('isMine');
    expect(RideModel.fromJson(json).isMine, isFalse);
  });

  group('NewRideModel.toJson', () {
    // Local times, as the form builds them: sent as UTC instants.
    final departure = DateTime.utc(2026, 11, 7, 7, 30).toLocal();
    NewRide newRide({String note = '', double? distanceKm}) => NewRide(
          pickup: ' Lac 2 (Tunis City) ',
          pickupTag: 'Lac 2',
          dropoff: 'ESPRIT Ghazela (Bloc E)',
          dropoffTag: 'ESPRIT Bloc E ',
          departure: departure,
          arrival: departure.add(const Duration(minutes: 35)),
          seatCount: 3,
          pricePerSeat: 2.5,
          carModel: 'Volkswagen Polo',
          carColor: 'Blue',
          plate: '231 TN 1187',
          amenities: const [RideAmenity.nonSmoking, RideAmenity.musicOk],
          dropoffNote: note,
          distanceKm: distanceKm,
        );

    test('is the body the backend test sent (trimmed, UTC, no empty optionals)', () {
      expect(NewRideModel.toJson(newRide()), _decode(newRideRequestJson));
    });

    test('sends the note and the distance when given', () {
      final json = NewRideModel.toJson(newRide(note: ' Bloc E parking ', distanceKm: 12.4));
      expect(json['dropoffNote'], 'Bloc E parking');
      expect(json['distanceKm'], 12.4);
    });

    test('leaves out a blank note', () {
      expect(NewRideModel.toJson(newRide(note: '   ')).containsKey('dropoffNote'), isFalse);
    });
  });

  test('RideModel skips amenities this app version does not know', () {
    final json = _decode(rideJson)..['amenities'] = ['musicOk', 'petFriendly'];
    expect(RideModel.fromJson(json).amenities, [RideAmenity.musicOk]);
  });

  test('RideModel.listFromJson reads every ride', () {
    final rides = RideModel.listFromJson(jsonDecode('[$rideJson,$rideJson]') as List<dynamic>);
    expect(rides.map((r) => r.id), ['es-4092', 'es-4092']);
  });

  test('CarpoolImpactModel.fromJson (backend fixture)', () {
    final impact = CarpoolImpactModel.fromJson(_decode(impactJson));
    expect(impact.savedKg, 1420.0);
    expect(impact.goalKg, 2000.0);
    expect(impact.percent, 71);
  });
}
