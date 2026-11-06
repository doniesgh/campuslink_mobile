import 'package:dio/dio.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/job.dart';
import '../../domain/repositories/job_repository.dart';
import '../models/job_models.dart';

/// Real implementation talking to the Node.js API (backend/src/modules/jobs).
class JobRepositoryImpl implements JobRepository {
  const JobRepositoryImpl(this._dio);
  final Dio _dio;

  @override
  Future<Result<List<Job>>> getJobs() => guard(() async {
        final r = await _dio.get<dynamic>(ApiEndpoints.jobs);
        return JobModel.listFromJson(r.data as List<dynamic>);
      });

  @override
  Future<Result<Job>> getJob(String id) => guard(() async {
        final r = await _dio.get<dynamic>(ApiEndpoints.job(id));
        return JobModel.fromJson(r.data as Map<String, dynamic>);
      });

  /// Applying twice comes back as a failure whose message
  /// ("You already applied to this offer.") is shown as-is.
  @override
  Future<Result<void>> apply(String jobId) => guard(() async {
        await _dio.post<dynamic>(ApiEndpoints.jobApplications(jobId));
      });
}
