import '../../../../core/error/result.dart';
import '../entities/job.dart';

abstract interface class JobRepository {
  Future<Result<List<Job>>> getJobs();
  Future<Result<Job>> getJob(String id);
  Future<Result<void>> apply(String jobId);
}
