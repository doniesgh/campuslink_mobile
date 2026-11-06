import 'package:dio/dio.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/academic_transcript.dart';
import '../../domain/repositories/grades_repository.dart';
import '../models/transcript_models.dart';

/// Real implementation talking to the Node.js API.
class GradesRepositoryImpl implements GradesRepository {
  const GradesRepositoryImpl(this._dio);
  final Dio _dio;

  @override
  Future<Result<AcademicTranscript>> getTranscript() => guard(() async {
        final r = await _dio.get<Map<String, dynamic>>(ApiEndpoints.transcript);
        return AcademicTranscriptModel.fromJson(r.data!).toEntity();
      });
}
