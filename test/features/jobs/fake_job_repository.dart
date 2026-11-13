import 'package:campuspulse/core/error/failures.dart';
import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/features/jobs/domain/entities/job.dart';
import 'package:campuspulse/features/jobs/domain/entities/job_application.dart';
import 'package:campuspulse/features/jobs/domain/entities/job_draft.dart';
import 'package:campuspulse/features/jobs/domain/entities/job_summary.dart';
import 'package:campuspulse/features/jobs/domain/repositories/job_repository.dart';

/// A [JobRepository] for widget tests: answers at once (no timers) with
/// [job], records what the screens send, and answers summaries with
/// [summaryAnswer] (a [Future] the test can hold back with a Completer).
class FakeJobRepository implements JobRepository {
  FakeJobRepository({this.job = sampleJob});

  Job job;
  final created = <JobDraft>[];
  final updated = <(String, JobDraft)>[];
  final deleted = <String>[];
  final cancelled = <String>[];
  final decided = <(String, String, bool)>[];
  List<JobApplication> applications = [];
  int summaryCalls = 0;
  Future<Result<JobSummary>> Function() summaryAnswer =
      () async => const Success(JobSummary(summary: 'A summary.'));

  @override
  Future<Result<List<Job>>> getJobs() async => Success([job]);

  @override
  Future<Result<Job>> getJob(String id) async =>
      id == job.id ? Success(job) : const Err(ServerFailure('Job not found.'));

  @override
  Future<Result<void>> apply(String jobId) async => const Success(null);

  @override
  Future<Result<List<JobApplication>>> getMyApplications() async => Success(applications);

  @override
  Future<Result<void>> cancelApplication(String jobId) async {
    cancelled.add(jobId);
    return const Success(null);
  }

  @override
  Future<Result<List<JobApplication>>> getJobApplications(String jobId) async =>
      Success([for (final a in applications) if (a.jobId == jobId) a]);

  @override
  Future<Result<JobApplication>> decideApplication(
    String jobId,
    String applicationId, {
    required bool accept,
  }) async {
    decided.add((jobId, applicationId, accept));
    final index = applications.indexWhere((a) => a.id == applicationId);
    if (index < 0) return const Err(ServerFailure('Application not found.'));
    final updatedApplication = applications[index].withStatus(
      accept ? ApplicationStatus.accepted : ApplicationStatus.rejected,
    );
    applications = [...applications]..[index] = updatedApplication;
    return Success(updatedApplication);
  }

  @override
  Future<Result<Job>> createJob(JobDraft draft) async {
    created.add(draft);
    return Success(_fromDraft('new-offer', draft));
  }

  @override
  Future<Result<Job>> updateJob(String id, JobDraft draft) async {
    updated.add((id, draft));
    job = _fromDraft(id, draft);
    return Success(job);
  }

  @override
  Future<Result<void>> deleteJob(String id) async {
    deleted.add(id);
    return const Success(null);
  }

  @override
  Future<Result<JobSummary>> summarize(String jobId) {
    summaryCalls++;
    return summaryAnswer();
  }

  static Job _fromDraft(String id, JobDraft draft) => Job(
        id: id,
        title: draft.title,
        company: draft.company,
        mission: draft.description,
        location: draft.location,
        period: draft.period,
        durationMonths: draft.durationMonths,
        stipendTnd: draft.stipendTnd,
        skills: draft.skills,
        tags: draft.tags,
        authorId: 'me',
        canEdit: true,
      );
}

/// An offer posted through the form: no rich fields.
const sampleJob = Job(
  id: 'offer-1',
  title: 'Flutter Mobile Intern',
  company: 'Medina Soft',
  mission: 'Build the Flutter app our clients use to book appointments every day.',
  location: 'Lac 1, Tunis',
  period: 'Feb – Jul 2026',
  durationMonths: 6,
  skills: ['Flutter', 'Dart'],
  tags: ['PFE 2026'],
  authorId: 'me',
  canEdit: true,
);