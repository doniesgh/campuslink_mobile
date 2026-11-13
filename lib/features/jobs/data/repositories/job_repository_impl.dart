import 'package:dio/dio.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/job.dart';
import '../../domain/entities/job_application.dart';
import '../../domain/entities/job_draft.dart';
import '../../domain/entities/job_summary.dart';
import '../../domain/repositories/job_repository.dart';
import '../models/job_models.dart';

/// Real implementation talking to the Node.js API (backend/src/modules/jobs).
class JobRepositoryImpl implements JobRepository {
  const JobRepositoryImpl(this._dio);
  final Dio _dio;

  /// The AI may take a while (the server gives it up to 50 s).
  static const _summaryTimeout = Duration(seconds: 60);

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

  @override
  Future<Result<List<JobApplication>>> getMyApplications() => guard(() async {
        final r = await _dio.get<dynamic>('${ApiEndpoints.jobs}/applications/mine');
        return JobApplicationModel.listFromJson(r.data as List<dynamic>);
      });

  /// Cancelling after the company answered comes back as a 409 failure
  /// ("This application has already been answered."), shown as-is.
  @override
  Future<Result<void>> cancelApplication(String jobId) => guard(() async {
        await _dio.delete<dynamic>(ApiEndpoints.jobApplications(jobId));
      });

  @override
  Future<Result<List<JobApplication>>> getJobApplications(String jobId) => guard(() async {
        final r = await _dio.get<dynamic>(ApiEndpoints.jobApplications(jobId));
        return JobApplicationModel.listFromJson(r.data as List<dynamic>);
      });

  @override
  Future<Result<JobApplication>> decideApplication(
    String jobId,
    String applicationId, {
    required bool accept,
  }) =>
      guard(() async {
        final r = await _dio.patch<dynamic>(
          '${ApiEndpoints.jobApplications(jobId)}/$applicationId',
          data: {'status': accept ? 'accepted' : 'rejected'},
        );
        return JobApplicationModel.fromJson(r.data as Map<String, dynamic>);
      });

  @override
  Future<Result<Job>> createJob(JobDraft draft) => guard(() async {
        final r = await _dio.post<dynamic>(ApiEndpoints.jobs, data: JobDraftModel.toJson(draft));
        return JobModel.fromJson(r.data as Map<String, dynamic>);
      });

  @override
  Future<Result<Job>> updateJob(String id, JobDraft draft) => guard(() async {
        final r = await _dio.patch<dynamic>(ApiEndpoints.job(id), data: JobDraftModel.toJson(draft));
        return JobModel.fromJson(r.data as Map<String, dynamic>);
      });

  @override
  Future<Result<void>> deleteJob(String id) => guard(() async {
        await _dio.delete<dynamic>(ApiEndpoints.job(id));
      });

  @override
  Future<Result<JobSummary>> summarize(String jobId) => guard(() async {
        final r = await _dio.post<dynamic>(
          ApiEndpoints.jobSummary(jobId),
          options: Options(receiveTimeout: _summaryTimeout),
        );
        return JobSummaryModel.fromJson(r.data as Map<String, dynamic>);
      });
}
