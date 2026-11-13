import '../../domain/entities/carpool_impact.dart';
import '../../domain/entities/new_ride.dart';
import '../../domain/entities/ride.dart';
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
        // Absent from older servers.
        isMine: (json['isMine'] as bool?) ?? false,
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

abstract final class NewRideModel {
  static Map<String, dynamic> toJson(NewRide ride) => {
        'pickup': ride.pickup.trim(),
        'pickupTag': ride.pickupTag.trim(),
        'dropoff': ride.dropoff.trim(),
        'dropoffTag': ride.dropoffTag.trim(),
        'departure': ride.departure.toUtc().toIso8601String(),
        'arrival': ride.arrival.toUtc().toIso8601String(),
        'seatCount': ride.seatCount,
        'pricePerSeat': ride.pricePerSeat,
        'carModel': ride.carModel.trim(),
        'carColor': ride.carColor.trim(),
        'plate': ride.plate.trim(),
        'amenities': [for (final a in ride.amenities) a.name],
        if (ride.dropoffNote.trim().isNotEmpty) 'dropoffNote': ride.dropoffNote.trim(),
        if (ride.distanceKm != null) 'distanceKm': ride.distanceKm,
      };
}

/// Backend impact JSON (GET /carpool/impact): { "savedKg": 1420, "goalKg": 2000 }
abstract final class CarpoolImpactModel {
  static CarpoolImpact fromJson(Map<String, dynamic> json) => CarpoolImpact(
        savedKg: (json['savedKg'] as num).toDouble(),
        goalKg: (json['goalKg'] as num).toDouble(),
      );
}
