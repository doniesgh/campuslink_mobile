import 'dart:convert';

import 'package:campuspulse/core/error/failures.dart';
import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/features/jobs/data/models/job_models.dart';
import 'package:campuspulse/features/jobs/data/repositories/mock_job_repository.dart';
import 'package:campuspulse/features/jobs/domain/entities/job_draft.dart';
import 'package:flutter_test/flutter_test.dart';

import 'job_fixtures.dart';

const _draft = JobDraft(
  title: 'Flutter Mobile Intern',
  company: 'Medina Soft',
  description: 'Build the Flutter app our clients use to book appointments every day, '
      'with a small team of three developers.',
  location: 'Lac 1, Tunis',
  durationMonths: 6,
  skills: ['Flutter', 'Dart'],
);

Failure _failureOf(Result<Object?> r) =>
    r.when(success: (_) => fail('expected a failure'), failure: (f) => f);

void main() {
  MockJobRepository repo() => MockJobRepository(latency: const Duration(milliseconds: 1));

  test('JobModel reads an offer posted through the form (rich fields null)', () {
    final job = JobModel.fromJson(jsonDecode(postedJobJson) as Map<String, dynamic>);

    expect(job.title, 'Flutter Mobile Intern');
    expect(job.companyLine, 'Medina Soft · Lac 1, Tunis');
    expect(job.canEdit, isTrue);
    expect(job.authorId, '6af7380cf0f064d23961643f');
    expect(job.stipendTnd, isNull);
    expect(job.durationMonths, 6);
    expect(job.matchPercent, isNull);
    expect(job.labGroup, isNull);
    expect(job.missionItems, isEmpty);
  });

  test('mock: a posted offer is listed first, editable, and can be edited then deleted', () async {
    final mock = repo();

    final posted = (await mock.createJob(_draft)).unwrap();
    expect(posted.canEdit, isTrue);
    expect(posted.matchPercent, isNull);
    final list = (await mock.getJobs()).unwrap();
    expect(list.first.id, posted.id);
    expect(list, hasLength(4));

    final edited = (await mock.updateJob(
      posted.id,
      JobDraft(title: 'Senior Flutter Intern', company: 'Medina Soft', description: 'x' * 30),
    ))
        .unwrap();
    expect(edited.title, 'Senior Flutter Intern');
    expect(edited.durationMonths, isNull);
    expect((await mock.getJob(posted.id)).unwrap().title, 'Senior Flutter Intern');

    expect(await mock.deleteJob(posted.id), isA<Success<void>>());
    expect(_failureOf(await mock.getJob(posted.id)).message, 'Job not found.');
    expect((await mock.getJobs()).unwrap(), hasLength(3));
  });

  test('mock: editing a seeded offer keeps its rich fields', () async {
    final mock = repo();
    final seeded = (await mock.getJob('nimbus-backend')).unwrap();

    final edited = (await mock.updateJob('nimbus-backend', JobDraft.fromJob(seeded))).unwrap();

    expect(edited.matchPercent, 81);
    expect(edited.labGroup, 'Platform');
    expect(edited.missionItems, hasLength(1));
  });

  test('mock: a canned summary, a 422 for a short offer and a 404 for an unknown one', () async {
    final mock = repo();

    final summary = (await mock.summarize('instadeep-ml')).unwrap();
    expect(summary.summary, startsWith('Junior AI & ML Research Intern at InstaDeep Ltd'));
    expect(summary.keyPoints, isNotEmpty);
    expect(summary.keyPoints.length, lessThanOrEqualTo(5));
    expect(summary.skills, contains('PyTorch'));
    expect(summary.idealFor, isNotEmpty);

    final short = (await mock.createJob(
      const JobDraft(title: 'Tiny', company: 'Medina Soft', description: 'Just a short one here.'),
    ))
        .unwrap();
    final tooShort = _failureOf(await mock.summarize(short.id));
    expect(tooShort, isA<ValidationFailure>());
    expect(tooShort.message, 'This offer is too short to summarise.');

    expect(_failureOf(await mock.summarize('unknown')).message, 'Job not found.');
    expect(_failureOf(await mock.deleteJob('unknown')).message, 'Job not found.');
  });
}
