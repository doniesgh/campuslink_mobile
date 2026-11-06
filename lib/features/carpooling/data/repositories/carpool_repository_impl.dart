import 'package:dio/dio.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/carpool_impact.dart';
import '../../domain/entities/new_ride.dart';
import '../../domain/entities/ride.dart';
import '../../domain/repositories/carpool_repository.dart';
import '../models/carpool_models.dart';

/// Real implementation talking to the Node.js API (backend/src/modules/carpool).
class CarpoolRepositoryImpl implements CarpoolRepository {
  const CarpoolRepositoryImpl(this._dio);
  final Dio _dio;

  @override
  Future<Result<List<Ride>>> getRides() => guard(() async {
        final r = await _dio.get<dynamic>(ApiEndpoints.rides);
        return RideModel.listFromJson(r.data as List<dynamic>);
      });

  @override
  Future<Result<Ride>> getRide(String id) => guard(() async {
        final r = await _dio.get<dynamic>(ApiEndpoints.ride(id));
        return RideModel.fromJson(r.data as Map<String, dynamic>);
      });

  /// A seat taken in the meantime, or a seat in the student's own ride,
  /// comes back as a failure whose message is shown as-is.
  @override
  Future<Result<void>> reserveSeats({
    required String rideId,
    required List<String> seatIds,
  }) =>
      guard(() async {
        await _dio.post<dynamic>(
          ApiEndpoints.rideReservations(rideId),
          data: {'seatIds': seatIds},
        );
      });

  @override
  Future<Result<CarpoolImpact>> getMonthlyImpact() => guard(() async {
        final r = await _dio.get<dynamic>(ApiEndpoints.carpoolImpact);
        return CarpoolImpactModel.fromJson(r.data as Map<String, dynamic>);
      });

  /// POST /carpool/rides. A ride the server refuses (422) comes back as a
  /// validation failure whose message, in French like the form, is shown as-is.
  @override
  Future<Result<Ride>> createRide(NewRide ride) => guard(() async {
        final r = await _dio.post<dynamic>(ApiEndpoints.rides, data: NewRideModel.toJson(ride));
        return RideModel.fromJson(r.data as Map<String, dynamic>);
      });
}
