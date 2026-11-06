import '../../domain/entities/carpool_impact.dart';
import '../../domain/entities/ride.dart';

/// Backend ride JSON (GET /carpool/rides, GET /carpool/rides/:id):
/// { "id": "es-4091", "code": "ES-4091", "pickup": "...", "dropoff": "...",
///   "pickupTag": "...", "dropoffTag": "...", "dropoffNote": "...",
///   "departure": "2026-11-06T12:15:00.000Z", "arrival": "...",
///   "distanceKm": 14.2, "pricePerSeat": 2.5, "driver": {...},
///   "seats": [{ "id": "s1", "label": "Sarra K.", "status": "driver" }, ...],
///   "amenities": ["nonSmoking", ...] }
///
/// Seat labels come ready to show ("You", a passenger's name, "Seat #3").
abstract final class RideModel {
  static Ride fromJson(Map<String, dynamic> json) => Ride(
        id: json['id'] as String,
        code: json['code'] as String,
        pickup: json['pickup'] as String,
        dropoff: json['dropoff'] as String,
        pickupTag: json['pickupTag'] as String,
        dropoffTag: json['dropoffTag'] as String,
        dropoffNote: json['dropoffNote'] as String,
        departure: DateTime.parse(json['departure'] as String).toLocal(),
        arrival: DateTime.parse(json['arrival'] as String).toLocal(),
        distanceKm: (json['distanceKm'] as num).toDouble(),
        pricePerSeat: (json['pricePerSeat'] as num).toDouble(),
        driver: _driver(json['driver'] as Map<String, dynamic>),
        seats: [
          for (final seat in json['seats'] as List<dynamic>) _seat(seat as Map<String, dynamic>),
        ],
        amenities: [
          // Amenities this app version doesn't know are skipped, not an error.
          for (final name in (json['amenities'] as List<dynamic>?) ?? const [])
            if (RideAmenity.values.asNameMap()[name] case final amenity?) amenity,
        ],
      );

  static List<Ride> listFromJson(List<dynamic> json) =>
      [for (final ride in json) fromJson(ride as Map<String, dynamic>)];

  static Driver _driver(Map<String, dynamic> json) => Driver(
        name: json['name'] as String,
        rating: (json['rating'] as num).toDouble(),
        profile: json['profile'] as String,
        ridesCompleted: (json['ridesCompleted'] as num).toInt(),
        carModel: json['carModel'] as String,
        carColor: json['carColor'] as String,
        plate: json['plate'] as String,
        isCarVerified: (json['isCarVerified'] as bool?) ?? false,
      );

  static Seat _seat(Map<String, dynamic> json) => Seat(
        id: json['id'] as String,
        label: json['label'] as String,
        status: SeatStatus.values.byName(json['status'] as String),
      );
}

/// Backend impact JSON (GET /carpool/impact): { "savedKg": 1420, "goalKg": 2000 }
abstract final class CarpoolImpactModel {
  static CarpoolImpact fromJson(Map<String, dynamic> json) => CarpoolImpact(
        savedKg: (json['savedKg'] as num).toDouble(),
        goalKg: (json['goalKg'] as num).toDouble(),
      );
}
