import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/job.dart';
import '../../domain/entities/job_application.dart';
import '../../domain/entities/job_draft.dart';
import '../../domain/entities/job_summary.dart';
import '../../domain/repositories/job_repository.dart';

/// In-memory fake (USE_MOCK=true): the API's offers, and posting, editing and
/// deleting in memory. Like the API, the seeded offers are not editable
/// (`canEdit` false; the screens let an admin edit them anyway).
class MockJobRepository implements JobRepository {
  /// [latency]: how long each call takes (unit tests shorten it).
  MockJobRepository({this.latency = const Duration(milliseconds: 500)});

  final Duration latency;

  static const List<Job> _jobs = [
    Job(
      id: 'instadeep-ml',
      featuredLabel: 'FEATURED RESEARCH OPENING',
      title: 'Junior AI & ML Research Intern',
      company: 'InstaDeep Ltd',
      location: 'Centre Urbain Nord, Tunis',
      tags: ['PFE 2025', 'Hybrid (3 days on-site)', 'Coeff PFE 20.0'],
      stipendTnd: 1200,
      durationMonths: 6,
      period: 'Feb – Jul 2025',
      labGroup: 'RL & AI',
      labGroupNote: 'Decision Lab',
      workspaceTitle: 'Tunis Lab Workspace & Cohort',
      workspaceBadges: ['14 Student Alumni · Current Interns', 'Bi-weekly London Sync'],
      mission: 'You will embed alongside the research group, translating theoretical '
          'breakthrough papers into high-performance reinforcement learning benchmarks '
          'and scalable multi-agent systems.',
      missionItems: [
        MissionItem(
          title: 'Deep RL Benchmarking',
          description: 'Design, iterate, and benchmark novel exploration strategies using '
              'PyTorch, JAX, and Flash-Attention primitives.',
        ),
        MissionItem(
          title: 'Global Research Bridges',
          description: 'Collaborate directly with lead research scientists across Tunis & '
              'London offices, presenting fortnightly lab findings.',
        ),
        MissionItem(
          title: 'Production-Grade Rollouts',
          description: 'Package validated algorithms into reproducible, open-source-ready '
              'containers for high-performance computing clusters.',
        ),
      ],
      matchPercent: 94,
      criteria: [
        'Strong foundational grasp of Python, Linear Algebra, and Deep RL algorithms.',
        'Registered in 4th/5th year at ESPRIT or equivalent engineering university (Graduation 2025).',
        'Demonstrated GitHub contributions, personal ML builds, or coursework in PyTorch/JAX.',
      ],
      skills: ['PyTorch', 'JAX', 'Reinforcement Learning', 'Git/Docker', 'CUDA'],
    ),
    Job(
      id: 'nimbus-backend',
      title: 'Backend Engineering Intern',
      company: 'Nimbus Labs',
      location: 'Lac 2, Tunis',
      tags: ['PFE 2025', 'On-site'],
      stipendTnd: 900,
      durationMonths: 6,
      period: 'Feb – Jul 2025',
      labGroup: 'Platform',
      labGroupNote: 'Core API team',
      workspaceTitle: 'Nimbus Lab Workspace',
      workspaceBadges: ['8 Current Interns'],
      mission: 'Build and operate REST services used by thousands of students.',
      missionItems: [
        MissionItem(
          title: 'API Development',
          description: 'Design and ship Node.js endpoints backed by MongoDB.',
        ),
      ],
      matchPercent: 81,
      criteria: ['Solid Node.js and REST fundamentals.', 'Comfortable with Git and code reviews.'],
      skills: ['Node.js', 'MongoDB', 'Docker'],
    ),
    Job(
      id: 'carthage-robotics',
      title: 'Computer Vision Intern',
      company: 'Carthage Robotics',
      location: 'Ghazela Technopark',
      tags: ['PFE 2025', 'Hybrid (2 days on-site)'],
      stipendTnd: 1000,
      durationMonths: 5,
      period: 'Mar – Jul 2025',
      labGroup: 'Vision',
      labGroupNote: 'Perception Lab',
      workspaceTitle: 'Carthage Robotics Lab',
      workspaceBadges: ['6 Current Interns'],
      mission: 'Prototype perception pipelines for autonomous warehouse robots.',
      missionItems: [
        MissionItem(
          title: 'Perception Prototyping',
          description: 'Train and evaluate detection models on real robot footage.',
        ),
      ],
      matchPercent: 76,
      criteria: ['Experience with OpenCV or PyTorch.', 'Interest in robotics.'],
      skills: ['Python', 'OpenCV', 'PyTorch'],
    ),
  ];

  /// The catalogue plus the offers posted in this session (newest first).
  final _offers = [..._jobs];

  /// Offers this fake student applied to (with where each stands), so "Applied"
  /// survives leaving the page.
  final _applied = <String, ApplicationStatus>{};

  /// Every application of this session: the student's own and, for the company
  /// side, a few fake applicants added the first time an offer's list is opened.
  final _applications = <JobApplication>[];
  final _withApplicants = <String>{};
  var _applicationCount = 0;
  var _posted = 0;

  static const _notFound = ServerFailure('Job not found.');

  Job? _find(String id) {
    for (final job in _offers) {
      if (job.id == id) return job;
    }
    return null;
  }

  Job _withState(Job job) {
    final status = _applied[job.id];
    final marked = job.withApplied(status != null);
    return status == null ? marked : _withStatus(marked, status);
  }

  Job _withStatus(Job job, ApplicationStatus status) => Job(
        id: job.id,
        title: job.title,
        company: job.company,
        mission: job.mission,
        location: job.location,
        tags: job.tags,
        stipendTnd: job.stipendTnd,
        durationMonths: job.durationMonths,
        period: job.period,
        labGroup: job.labGroup,
        labGroupNote: job.labGroupNote,
        workspaceTitle: job.workspaceTitle,
        workspaceBadges: job.workspaceBadges,
        missionItems: job.missionItems,
        matchPercent: job.matchPercent,
        criteria: job.criteria,
        skills: job.skills,
        featuredLabel: job.featuredLabel,
        hasApplied: true,
        applicationStatus: status,
        authorId: job.authorId,
        canEdit: job.canEdit,
      );

  @override
  Future<Result<List<Job>>> getJobs() async {
    await Future<void>.delayed(latency);
    return Success([for (final job in _offers) _withState(job)]);
  }

  @override
  Future<Result<Job>> getJob(String id) async {
    await Future<void>.delayed(latency);
    final job = _find(id);
    return job == null ? const Err(_notFound) : Success(_withState(job));
  }

  /// Same answers as the API: 404-like for unknown offers, 409-like when applying twice.
  @override
  Future<Result<void>> apply(String jobId) async {
    await Future<void>.delayed(latency);
    if (_find(jobId) == null) return const Err(_notFound);
    if (_applied.containsKey(jobId)) {
      return const Err(ServerFailure('You already applied to this offer.'));
    }
    _applied[jobId] = ApplicationStatus.pending;
    final job = _find(jobId)!;
    _applications.add(JobApplication(
      id: 'mock-application-${++_applicationCount}',
      jobId: jobId,
      status: ApplicationStatus.pending,
      appliedAt: DateTime.now(),
      jobTitle: job.title,
      company: job.company,
      location: job.location,
      applicantName: 'You (demo student)',
      applicantEmail: 'student@campus.test',
    ));
    return const Success(null);
  }

  @override
  Future<Result<List<JobApplication>>> getMyApplications() async {
    await Future<void>.delayed(latency);
    final mine = [
      for (final application in _applications)
        if (_applied.containsKey(application.jobId) && application.applicantName.startsWith('You'))
          application,
    ];
    return Success(mine.reversed.toList());
  }

  /// 409-like once the company answered, as the API.
  @override
  Future<Result<void>> cancelApplication(String jobId) async {
    await Future<void>.delayed(latency);
    final status = _applied[jobId];
    if (status == null) return const Err(ServerFailure('Application not found.'));
    if (status != ApplicationStatus.pending) {
      return const Err(ServerFailure('This application has already been answered.'));
    }
    _applied.remove(jobId);
    _applications.removeWhere((a) => a.jobId == jobId && a.applicantName.startsWith('You'));
    return const Success(null);
  }

  @override
  Future<Result<List<JobApplication>>> getJobApplications(String jobId) async {
    await Future<void>.delayed(latency);
    if (_find(jobId) == null) return const Err(_notFound);
    if (_withApplicants.add(jobId)) {
      for (final (name, email) in const [
        ('Sarra Ben Ali', 'sarra.benali@campus.test'),
        ('Yassine Trabelsi', 'yassine.trabelsi@campus.test'),
      ]) {
        _applications.add(JobApplication(
          id: 'mock-application-${++_applicationCount}',
          jobId: jobId,
          status: ApplicationStatus.pending,
          appliedAt: DateTime.now().subtract(Duration(days: _applicationCount)),
          applicantName: name,
          applicantEmail: email,
        ));
      }
    }
    return Success([for (final a in _applications) if (a.jobId == jobId) a]);
  }

  @override
  Future<Result<JobApplication>> decideApplication(
    String jobId,
    String applicationId, {
    required bool accept,
  }) async {
    await Future<void>.delayed(latency);
    final index = _applications.indexWhere((a) => a.id == applicationId && a.jobId == jobId);
    if (index < 0) return const Err(ServerFailure('Application not found.'));
    final current = _applications[index];
    if (!current.isPending) {
      return const Err(ServerFailure('This application has already been answered.'));
    }
    final status = accept ? ApplicationStatus.accepted : ApplicationStatus.rejected;
    final updated = current.withStatus(status);
    _applications[index] = updated;
    if (current.applicantName.startsWith('You')) _applied[jobId] = status;
    return Success(updated);
  }

  /// Posted by "me": editable, listed first, without the catalogue's rich fields.
  @override
  Future<Result<Job>> createJob(JobDraft draft) async {
    await Future<void>.delayed(latency);
    _posted++;
    final job = _fromDraft('mock-job-$_posted', draft);
    _offers.insert(0, job);
    return Success(job);
  }

  /// Replaces what the form edits; the catalogue's rich fields stay.
  @override
  Future<Result<Job>> updateJob(String id, JobDraft draft) async {
    await Future<void>.delayed(latency);
    final old = _find(id);
    if (old == null) return const Err(_notFound);
    final job = Job(
      id: id,
      title: draft.title.trim(),
      company: draft.company.trim(),
      mission: draft.description.trim(),
      location: draft.location.trim(),
      period: draft.period.trim(),
      durationMonths: draft.durationMonths,
      stipendTnd: draft.stipendTnd,
      skills: draft.skills,
      tags: draft.tags,
      featuredLabel: old.featuredLabel,
      labGroup: old.labGroup,
      labGroupNote: old.labGroupNote,
      workspaceTitle: old.workspaceTitle,
      workspaceBadges: old.workspaceBadges,
      missionItems: old.missionItems,
      matchPercent: old.matchPercent,
      criteria: old.criteria,
      authorId: old.authorId,
      canEdit: old.canEdit,
    );
    _offers[_offers.indexOf(old)] = job;
    return Success(_withState(job));
  }

  @override
  Future<Result<void>> deleteJob(String id) async {
    await Future<void>.delayed(latency);
    final job = _find(id);
    if (job == null) return const Err(_notFound);
    _offers.remove(job);
    _applied.remove(id);
    _applications.removeWhere((a) => a.jobId == id);
    return const Success(null);
  }

  /// A canned summary built from the offer (no AI offline), with the API's
  /// 422 for an offer too short to summarise.
  @override
  Future<Result<JobSummary>> summarize(String jobId) async {
    await Future<void>.delayed(latency);
    final job = _find(jobId);
    if (job == null) return const Err(_notFound);
    final described = [
      job.mission,
      for (final item in job.missionItems) item.description,
      ...job.criteria,
    ].join(' ').trim();
    if (described.length < 80) {
      return const Err(ValidationFailure('This offer is too short to summarise.'));
    }
    return Success(
      JobSummary(
        summary: '${job.title} at ${job.company}'
            '${job.location.isEmpty ? '' : ', ${job.location}'}. ${job.mission.trim()}',
        keyPoints: [
          for (final item in job.missionItems.take(3)) item.title,
          if (job.durationMonths != null) '${job.durationMonths} months',
          if (job.stipendTnd != null) '${job.stipendTnd} TND per month',
          if (job.period.isNotEmpty) job.period,
        ].take(5).toList(),
        skills: job.skills.take(8).toList(),
        idealFor: 'A student who wants hands-on experience with ${job.company}.',
        model: 'mock',
      ),
    );
  }

  static Job _fromDraft(String id, JobDraft draft) => Job(
        id: id,
        title: draft.title.trim(),
        company: draft.company.trim(),
        mission: draft.description.trim(),
        location: draft.location.trim(),
        period: draft.period.trim(),
        durationMonths: draft.durationMonths,
        stipendTnd: draft.stipendTnd,
        skills: draft.skills,
        tags: draft.tags,
        authorId: 'mock-me',
        canEdit: true,
      );
}
