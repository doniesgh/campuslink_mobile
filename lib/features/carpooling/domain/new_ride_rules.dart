import 'entities/new_ride.dart';

/// The fields of a [NewRide], to report errors next to the right input.
enum NewRideField {
  pickup,
  pickupTag,
  dropoff,
  dropoffTag,
  departure,
  arrival,
  seatCount,
  pricePerSeat,
  carModel,
  carColor,
  plate,
  dropoffNote,
  distanceKm,
}

/// Rules of a published ride. They are the server's rules, with the same
/// (French) messages: backend/src/modules/carpool/carpool.schemas.ts.
/// Change both together.
///
/// Each check returns the message to show, or null when the value is valid.
abstract final class NewRideRules {
  static const placeMaxLength = 80;
  static const tagMaxLength = 24;
  static const carModelMaxLength = 40;
  static const carColorMaxLength = 20;
  static const plateMaxLength = 20;
  static const noteMaxLength = 140;
  static const minSeats = 1;
  static const maxSeats = 4;
  static const maxPricePerSeat = 50.0;
  static const minDistanceKm = 0.1;
  static const maxDistanceKm = 1000.0;

  static const seatsMessage = 'Proposez entre $minSeats et $maxSeats places.';
  static const priceMessage = 'Le prix par place doit être entre 0 et 50 TND.';
  static const distanceMessage = 'La distance doit être entre 0,1 et 1000 km.';

  static String? _text(String? value, int max, String missing, String tooLong) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return missing;
    return v.length > max ? tooLong : null;
  }

  static String? pickup(String? value) => _text(
        value,
        placeMaxLength,
        'Indiquez le point de départ.',
        'Le point de départ est trop long ($placeMaxLength caractères max).',
      );

  static String? pickupTag(String? value) => _text(
        value,
        tagMaxLength,
        'Ajoutez un repère court pour le départ.',
        'Le repère du départ est trop long ($tagMaxLength caractères max).',
      );

  static String? dropoff(String? value) => _text(
        value,
        placeMaxLength,
        'Indiquez la destination.',
        'La destination est trop longue ($placeMaxLength caractères max).',
      );

  static String? dropoffTag(String? value) => _text(
        value,
        tagMaxLength,
        'Ajoutez un repère court pour la destination.',
        'Le repère de la destination est trop long ($tagMaxLength caractères max).',
      );

  /// The departure must be after [now].
  static String? departure(DateTime? departure, {required DateTime now}) {
    if (departure == null) return "Choisissez l'heure de départ.";
    return departure.isAfter(now) ? null : 'Le départ doit être dans le futur.';
  }

  static String? arrival(DateTime? arrival, {required DateTime? departure}) {
    if (arrival == null) return "Indiquez l'heure d'arrivée.";
    if (departure == null) return null;
    return arrival.isAfter(departure) ? null : "L'arrivée doit être après le départ.";
  }

  static String? seatCount(int? value) =>
      value == null || value < minSeats || value > maxSeats ? seatsMessage : null;

  /// 0 means free.
  static String? pricePerSeat(double? value) =>
      value == null || value.isNaN || value < 0 || value > maxPricePerSeat ? priceMessage : null;

  static String? carModel(String? value) => _text(
        value,
        carModelMaxLength,
        'Indiquez le modèle de la voiture.',
        'Le modèle est trop long ($carModelMaxLength caractères max).',
      );

  static String? carColor(String? value) => _text(
        value,
        carColorMaxLength,
        'Indiquez la couleur de la voiture.',
        'La couleur est trop longue ($carColorMaxLength caractères max).',
      );

  static String? plate(String? value) => _text(
        value,
        plateMaxLength,
        "Indiquez la plaque d'immatriculation.",
        'La plaque est trop longue ($plateMaxLength caractères max).',
      );

  /// Optional.
  static String? dropoffNote(String? value) => (value?.trim().length ?? 0) > noteMaxLength
      ? 'La note est trop longue ($noteMaxLength caractères max).'
      : null;

  /// Optional: null means not given.
  static String? distanceKm(double? value) {
    if (value == null) return null;
    return value.isNaN || value < minDistanceKm || value > maxDistanceKm ? distanceMessage : null;
  }

  /// The optional distance as typed: blank means not given, and both "14,2"
  /// and "14.2" are read. Text that isn't a number gets the distance message.
  static String? distanceText(String? text) {
    final v = text?.trim() ?? '';
    if (v.isEmpty) return null;
    final km = parseDistance(v);
    return km == null ? distanceMessage : distanceKm(km);
  }

  /// "14,2" or "14.2" -> 14.2; blank or not a number -> null.
  static double? parseDistance(String? text) {
    final v = text?.trim().replaceAll(',', '.') ?? '';
    return v.isEmpty ? null : double.tryParse(v);
  }
}

/// Every problem of [ride], by field, in the order of the form. Empty when
/// the ride can be published. [now] is the moment the departure must follow.
Map<NewRideField, String> validateNewRide(NewRide ride, {required DateTime now}) {
  final checks = <NewRideField, String?>{
    NewRideField.pickup: NewRideRules.pickup(ride.pickup),
    NewRideField.pickupTag: NewRideRules.pickupTag(ride.pickupTag),
    NewRideField.dropoff: NewRideRules.dropoff(ride.dropoff),
    NewRideField.dropoffTag: NewRideRules.dropoffTag(ride.dropoffTag),
    NewRideField.departure: NewRideRules.departure(ride.departure, now: now),
    NewRideField.arrival: NewRideRules.arrival(ride.arrival, departure: ride.departure),
    NewRideField.seatCount: NewRideRules.seatCount(ride.seatCount),
    NewRideField.pricePerSeat: NewRideRules.pricePerSeat(ride.pricePerSeat),
    NewRideField.carModel: NewRideRules.carModel(ride.carModel),
    NewRideField.carColor: NewRideRules.carColor(ride.carColor),
    NewRideField.plate: NewRideRules.plate(ride.plate),
    NewRideField.dropoffNote: NewRideRules.dropoffNote(ride.dropoffNote),
    NewRideField.distanceKm: NewRideRules.distanceKm(ride.distanceKm),
  };
  return {
    for (final MapEntry(:key, :value) in checks.entries)
      if (value != null) key: value,
  };
}
