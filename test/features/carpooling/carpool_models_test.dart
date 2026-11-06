import 'dart:convert';

import 'package:campuspulse/features/carpooling/data/models/carpool_models.dart';
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
