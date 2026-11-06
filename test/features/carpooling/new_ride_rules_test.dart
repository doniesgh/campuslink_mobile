import 'package:campuspulse/features/carpooling/domain/entities/new_ride.dart';
import 'package:campuspulse/features/carpooling/domain/entities/ride.dart';
import 'package:campuspulse/features/carpooling/domain/new_ride_rules.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 6, 10);

/// A valid ride leaving tomorrow at 08:30; [departure] and [arrival] override it.
NewRide _ride({
  String pickup = 'Lac 2 (Tunis City)',
  String pickupTag = 'Lac 2',
  String dropoff = 'ESPRIT Ghazela (Bloc E)',
  String dropoffTag = 'ESPRIT Bloc E',
  DateTime? departure,
  DateTime? arrival,
  int seatCount = 3,
  double pricePerSeat = 2.5,
  String carModel = 'Volkswagen Polo',
  String carColor = 'Blue',
  String plate = '231 TN 1187',
  String dropoffNote = '',
  double? distanceKm,
}) {
  final leaves = departure ?? DateTime(2026, 11, 7, 8, 30);
  return NewRide(
    pickup: pickup,
    pickupTag: pickupTag,
    dropoff: dropoff,
    dropoffTag: dropoffTag,
    departure: leaves,
    arrival: arrival ?? leaves.add(const Duration(minutes: 35)),
    seatCount: seatCount,
    pricePerSeat: pricePerSeat,
    carModel: carModel,
    carColor: carColor,
    plate: plate,
    amenities: const [RideAmenity.nonSmoking],
    dropoffNote: dropoffNote,
    distanceKm: distanceKm,
  );
}

Map<NewRideField, String> _errors(NewRide ride) => validateNewRide(ride, now: _now);

String _x(int n) => 'x' * n;

void main() {
  test('a complete ride has no errors', () {
    expect(_errors(_ride()), isEmpty);
    expect(_errors(_ride(dropoffNote: 'Bloc E parking', distanceKm: 12.4)), isEmpty);
  });

  // The same rules and messages as backend/test/carpool-create.test.ts.
  group('reports each rule of the server, with its message', () {
    final cases = <String, (NewRide, NewRideField, String)>{
      'departure in the past': (
        _ride(departure: _now.subtract(const Duration(minutes: 1))),
        NewRideField.departure,
        'Le départ doit être dans le futur.',
      ),
      'departure right now': (
        _ride(departure: _now),
        NewRideField.departure,
        'Le départ doit être dans le futur.',
      ),
      'arrival at the departure time': (
        _ride(departure: DateTime(2026, 11, 7, 8, 30), arrival: DateTime(2026, 11, 7, 8, 30)),
        NewRideField.arrival,
        "L'arrivée doit être après le départ.",
      ),
      'arrival before departure': (
        _ride(departure: DateTime(2026, 11, 7, 8, 30), arrival: DateTime(2026, 11, 7, 8)),
        NewRideField.arrival,
        "L'arrivée doit être après le départ.",
      ),
      '0 seats': (_ride(seatCount: 0), NewRideField.seatCount, 'Proposez entre 1 et 4 places.'),
      '5 seats': (_ride(seatCount: 5), NewRideField.seatCount, 'Proposez entre 1 et 4 places.'),
      'a negative price': (
        _ride(pricePerSeat: -0.5),
        NewRideField.pricePerSeat,
        'Le prix par place doit être entre 0 et 50 TND.',
      ),
      'a price above 50 TND': (
        _ride(pricePerSeat: 50.5),
        NewRideField.pricePerSeat,
        'Le prix par place doit être entre 0 et 50 TND.',
      ),
      'blank pickup': (_ride(pickup: '   '), NewRideField.pickup, 'Indiquez le point de départ.'),
      'pickup too long': (
        _ride(pickup: _x(81)),
        NewRideField.pickup,
        'Le point de départ est trop long (80 caractères max).',
      ),
      'blank pickup tag': (
        _ride(pickupTag: ''),
        NewRideField.pickupTag,
        'Ajoutez un repère court pour le départ.',
      ),
      'pickup tag too long': (
        _ride(pickupTag: _x(25)),
        NewRideField.pickupTag,
        'Le repère du départ est trop long (24 caractères max).',
      ),
      'blank dropoff': (_ride(dropoff: ' '), NewRideField.dropoff, 'Indiquez la destination.'),
      'dropoff too long': (
        _ride(dropoff: _x(81)),
        NewRideField.dropoff,
        'La destination est trop longue (80 caractères max).',
      ),
      'blank dropoff tag': (
        _ride(dropoffTag: ''),
        NewRideField.dropoffTag,
        'Ajoutez un repère court pour la destination.',
      ),
      'dropoff tag too long': (
        _ride(dropoffTag: _x(25)),
        NewRideField.dropoffTag,
        'Le repère de la destination est trop long (24 caractères max).',
      ),
      'blank car model': (
        _ride(carModel: ''),
        NewRideField.carModel,
        'Indiquez le modèle de la voiture.',
      ),
      'car model too long': (
        _ride(carModel: _x(41)),
        NewRideField.carModel,
        'Le modèle est trop long (40 caractères max).',
      ),
      'blank car color': (
        _ride(carColor: '  '),
        NewRideField.carColor,
        'Indiquez la couleur de la voiture.',
      ),
      'car color too long': (
        _ride(carColor: _x(21)),
        NewRideField.carColor,
        'La couleur est trop longue (20 caractères max).',
      ),
      'blank plate': (_ride(plate: ''), NewRideField.plate, "Indiquez la plaque d'immatriculation."),
      'plate too long': (
        _ride(plate: _x(21)),
        NewRideField.plate,
        'La plaque est trop longue (20 caractères max).',
      ),
      'note too long': (
        _ride(dropoffNote: _x(141)),
        NewRideField.dropoffNote,
        'La note est trop longue (140 caractères max).',
      ),
      'distance of 0 km': (
        _ride(distanceKm: 0),
        NewRideField.distanceKm,
        'La distance doit être entre 0,1 et 1000 km.',
      ),
      'distance above 1000 km': (
        _ride(distanceKm: 1000.5),
        NewRideField.distanceKm,
        'La distance doit être entre 0,1 et 1000 km.',
      ),
    };

    cases.forEach((name, testCase) {
      final (ride, field, message) = testCase;
      test(name, () => expect(_errors(ride), {field: message}));
    });
  });

  test('the limits are inclusive, and lengths are counted after trimming', () {
    final ride = _ride(
      pickup: '  ${_x(80)}  ',
      pickupTag: _x(24),
      dropoff: _x(80),
      dropoffTag: _x(24),
      seatCount: 4,
      pricePerSeat: 50,
      carModel: _x(40),
      carColor: _x(20),
      plate: _x(20),
      dropoffNote: _x(140),
      distanceKm: 1000,
    );
    expect(_errors(ride), isEmpty);
    expect(_errors(_ride(seatCount: 1, pricePerSeat: 0, distanceKm: 0.1)), isEmpty);
  });

  test('lists every problem, in the order of the form', () {
    final errors = _errors(
      _ride(pickup: '', carModel: '', departure: _now, seatCount: 9),
    );
    expect(errors.keys, [
      NewRideField.pickup,
      NewRideField.departure,
      NewRideField.seatCount,
      NewRideField.carModel,
    ]);
  });

  group('field checks used by the form', () {
    test('departure and arrival accept a missing value only as an error', () {
      expect(NewRideRules.departure(null, now: _now), "Choisissez l'heure de départ.");
      expect(NewRideRules.arrival(null, departure: _now), "Indiquez l'heure d'arrivée.");
      // No departure yet: that's the departure's error, not the arrival's.
      expect(NewRideRules.arrival(_now, departure: null), isNull);
    });

    test('price and seats refuse a missing or NaN value', () {
      expect(NewRideRules.seatCount(null), 'Proposez entre 1 et 4 places.');
      expect(NewRideRules.pricePerSeat(null), isNotNull);
      expect(NewRideRules.pricePerSeat(double.nan), isNotNull);
      expect(NewRideRules.distanceKm(double.nan), isNotNull);
    });

    test('the distance field reads "14,2" and "14.2", and blank means not given', () {
      expect(NewRideRules.parseDistance('14,2'), 14.2);
      expect(NewRideRules.parseDistance(' 14.2 '), 14.2);
      expect(NewRideRules.parseDistance(''), isNull);
      expect(NewRideRules.parseDistance('loin'), isNull);

      expect(NewRideRules.distanceText(''), isNull);
      expect(NewRideRules.distanceText('  '), isNull);
      expect(NewRideRules.distanceText('14,2'), isNull);
      expect(NewRideRules.distanceText('loin'), 'La distance doit être entre 0,1 et 1000 km.');
      expect(NewRideRules.distanceText('0'), 'La distance doit être entre 0,1 et 1000 km.');
      expect(NewRideRules.distanceText('2000'), 'La distance doit être entre 0,1 et 1000 km.');
    });

    test('the note is optional', () {
      expect(NewRideRules.dropoffNote(null), isNull);
      expect(NewRideRules.dropoffNote(''), isNull);
      expect(NewRideRules.dropoffNote('  ${_x(140)}  '), isNull);
    });
  });
}
