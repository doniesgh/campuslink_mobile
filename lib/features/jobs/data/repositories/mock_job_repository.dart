import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/job.dart';
import '../../domain/repositories/job_repository.dart';

/// In-memory fake. Replace with a Dio-based implementation when the API exists.
class MockJobRepository implements JobRepository {
  static const _latency = Duration(milliseconds: 500);

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

  /// Offers this fake student applied to, so "Applied" survives leaving the page.
  final _applied = <String>{};

  @override
  Future<Result<List<Job>>> getJobs() async {
    await Future<void>.delayed(_latency);
    return Success([for (final job in _jobs) job.withApplied(_applied.contains(job.id))]);
  }

  @override
  Future<Result<Job>> getJob(String id) async {
    await Future<void>.delayed(_latency);
    for (final job in _jobs) {
      if (job.id == id) return Success(job.withApplied(_applied.contains(id)));
    }
    return const Err(ServerFailure('Job not found.'));
  }

  /// Same answers as the API: 404-like for unknown offers, 409-like when applying twice.
  @override
  Future<Result<void>> apply(String jobId) async {
    await Future<void>.delayed(_latency);
    if (!_jobs.any((job) => job.id == jobId)) return const Err(ServerFailure('Job not found.'));
    if (!_applied.add(jobId)) {
      return const Err(ServerFailure('You already applied to this offer.'));
    }
    return const Success(null);
  }
}
