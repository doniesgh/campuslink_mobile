import 'dart:convert';

import 'package:campuspulse/features/jobs/data/models/job_models.dart';
import 'package:campuspulse/features/jobs/data/repositories/mock_job_repository.dart';
import 'package:campuspulse/features/jobs/domain/entities/job.dart';
import 'package:flutter_test/flutter_test.dart';

import 'job_fixtures.dart';

/// Every field, so two offers can be compared as plain values.
List<Object?> _fields(Job j) => [
      j.id,
      j.featuredLabel,
      j.title,
      j.company,
      j.location,
      j.tags,
      j.stipendTnd,
      j.durationMonths,
      j.period,
      j.labGroup,
      j.labGroupNote,
      j.workspaceTitle,
      j.workspaceBadges,
      j.mission,
      [for (final m in j.missionItems) (m.title, m.description)],
      j.matchPercent,
      j.criteria,
      j.skills,
    ];

void main() {
  final jobs = JobModel.listFromJson(jsonDecode(jobsJson) as List<dynamic>);

  test('JobModel reads the backend fixture', () {
    expect(jobs.map((j) => j.id), ['instadeep-ml', 'nimbus-backend', 'carthage-robotics']);

    final featured = jobs.first;
    expect(featured.isFeatured, isTrue);
    expect(featured.featuredLabel, 'FEATURED RESEARCH OPENING');
    expect(featured.title, 'Junior AI & ML Research Intern');
    expect(featured.company, 'InstaDeep Ltd');
    expect(featured.companyInitials, 'IL');
    expect(featured.tags, ['PFE 2025', 'Hybrid (3 days on-site)', 'Coeff PFE 20.0']);
    expect(featured.stipendTnd, 1200);
    expect(featured.durationMonths, 6);
    expect(featured.period, 'Feb – Jul 2025');
    expect(featured.workspaceBadges, ['14 Student Alumni · Current Interns', 'Bi-weekly London Sync']);
    expect(featured.missionItems.map((m) => m.title), [
      'Deep RL Benchmarking',
      'Global Research Bridges',
      'Production-Grade Rollouts',
    ]);
    expect(featured.matchPercent, 94);
    expect(featured.skills, hasLength(5));

    expect(jobs[1].featuredLabel, isNull);
    expect(jobs[1].isFeatured, isFalse);
  });

  test('the API serves the same offers as the mock', () async {
    final mock = (await MockJobRepository().getJobs()).unwrap();
    expect(jobs.map(_fields).toList(), mock.map(_fields).toList());
  });

  test('JobModel tolerates missing lists', () {
    final json = (jsonDecode(jobsJson) as List<dynamic>).first as Map<String, dynamic>
      ..remove('tags')
      ..remove('missionItems');
    final job = JobModel.fromJson(json);
    expect(job.tags, isEmpty);
    expect(job.missionItems, isEmpty);
  });
}
