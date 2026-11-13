import 'package:dio/dio.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/timetable_slot.dart';
import '../../domain/repositories/timetable_admin_repository.dart';
import '../models/timetable_admin_models.dart';

/// The admin timetable API (/admin/timetable/slots).
class TimetableAdminRepositoryImpl implements TimetableAdminRepository {
  const TimetableAdminRepositoryImpl(this._dio);
  final Dio _dio;

  /// The server's code of a 409 for a class that clashes with others.
  static const conflictCode = 'TIMETABLE_CONFLICT';

  @override
  Future<Result<List<TimetableSlot>>> getSlots() => guard(() async {
        final r = await _dio.get<dynamic>(ApiEndpoints.adminTimetableSlots);
        return timetableSlotsFromJson(r.data as Map<String, dynamic>);
      });

  @override
  Future<Result<SlotSaveOutcome>> createSlot(SlotDraft draft) =>
      _save(() => _dio.post<dynamic>(ApiEndpoints.adminTimetableSlots, data: draft.toJson()));

  @override
  Future<Result<SlotSaveOutcome>> updateSlot(String id, SlotDraft draft) =>
      _save(() => _dio.patch<dynamic>(ApiEndpoints.adminTimetableSlot(id), data: draft.toJson()));

  @override
  Future<Result<void>> deleteSlot(String id) =>
      guard(() => _dio.delete<dynamic>(ApiEndpoints.adminTimetableSlot(id)));

  /// A 409 `TIMETABLE_CONFLICT` is an answer (the clashing classes), not a failure.
  Future<Result<SlotSaveOutcome>> _save(Future<Response<dynamic>> Function() send) async {
    try {
      final r = await send();
      return Success(SlotSaved(timetableSlotFromJson(r.data as Map<String, dynamic>)));
    } on DioException catch (e) {
      final data = e.response?.data;
      if (e.response?.statusCode == 409 && data is Map<String, dynamic> && data['code'] == conflictCode) {
        return Success(slotClashFromJson(data));
      }
      return Err(mapDioException(e));
    } catch (_) {
      return const Err(UnknownFailure());
    }
  }
}
