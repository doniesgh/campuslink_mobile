import 'package:dio/dio.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/class_session.dart';
import '../../domain/entities/timetable_week.dart';
import '../../domain/repositories/timetable_repository.dart';
import '../models/timetable_models.dart';

/// Timetable from the Node.js API. The day is sent as its calendar date
/// ('YYYY-MM-DD'), so the server never has to guess the phone's time zone.
class TimetableRepositoryImpl implements TimetableRepository {
  const TimetableRepositoryImpl(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> _get(String path, DateTime day) async {
    final r = await _dio.get<dynamic>(path, queryParameters: {'date': formatApiDate(day)});
    return r.data as Map<String, dynamic>;
  }

  @override
  Future<Result<TimetableDay>> getDay(DateTime day) =>
      guard(() async => timetableDayFromJson(await _get(ApiEndpoints.timetableDay, day)));

  @override
  Future<Result<TimetableWeek>> getWeek(DateTime day) =>
      guard(() async => timetableWeekFromJson(await _get(ApiEndpoints.timetableWeek, day)));
}
