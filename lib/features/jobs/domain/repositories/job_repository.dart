import '../../../../core/error/result.dart';
import '../entities/job.dart';
import '../entities/job_application.dart';
import '../entities/job_draft.dart';
import '../entities/job_summary.dart';

abstract interface class JobRepository {
  Future<Result<List<Job>>> getJobs();
  Future<Result<Job>> getJob(String id);
  Future<Result<void>> apply(String jobId);

  /// The student's own applications, newest first. Students only.
  Future<Result<List<JobApplication>>> getMyApplications();

  /// Withdraws the student's application. Only while it is pending (409 once answered).
  Future<Result<void>> cancelApplication(String jobId);

  /// The applications received by an offer. Its author or an admin only (403 otherwise).
  Future<Result<List<JobApplication>>> getJobApplications(String jobId);

  /// Accepts or refuses a pending application. Its author or an admin only.
  Future<Result<JobApplication>> decideApplication(
    String jobId,
    String applicationId, {
    required bool accept,
  });

  /// Companies and admins only (the API answers 403 otherwise).
  Future<Result<Job>> createJob(JobDraft draft);

  /// Its author or an admin only (403 otherwise).
  Future<Result<Job>> updateJob(String id, JobDraft draft);

  /// Its author or an admin only (403 otherwise).
  Future<Result<void>> deleteJob(String id);

  /// The AI summary. Fails with the server's `code`: `AI_UNAVAILABLE` (no AI
  /// on the server), `AI_NO_CREDITS`, `AI_BUSY`, `AI_FAILED`, or
  /// `TOO_MANY_REQUESTS` (the user's hourly limit).
  Future<Result<JobSummary>> summarize(String jobId);
}
