import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/features/jobs/data/models/job_models.dart';
import 'package:campuspulse/features/jobs/data/repositories/mock_job_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json({Object? hasApplied}) => {
      'id': 'nimbus-backend',
      'featuredLabel': null,
      'title': 'Backend Engineering Intern',
      'company': 'Nimbus Labs',
      'location': 'Lac 2, Tunis',
      'tags': <String>[],
      'stipendTnd': 900,
      'durationMonths': 6,
      'period': 'Feb – Jul 2025',
      'labGroup': 'Platform',
      'labGroupNote': 'Core API team',
      'workspaceTitle': 'Nimbus Lab Workspace',
      'workspaceBadges': <String>[],
      'mission': 'Build REST services.',
      'missionItems': <Object>[],
      'matchPercent': 81,
      'criteria': <String>[],
      'skills': <String>[],
      if (hasApplied != null) 'hasApplied': hasApplied,
    };

void main() {
  test('hasApplied comes from the API, false when the field is missing', () {
    expect(JobModel.fromJson(_json(hasApplied: true)).hasApplied, isTrue);
    expect(JobModel.fromJson(_json(hasApplied: false)).hasApplied, isFalse);
    expect(JobModel.fromJson(_json()).hasApplied, isFalse);
  });

  test('withApplied keeps every other field', () {
    final job = JobModel.fromJson(_json());
    final applied = job.withApplied(true);
    expect(applied.hasApplied, isTrue);
    expect(applied.id, job.id);
    expect(applied.company, job.company);
    expect(applied.matchPercent, job.matchPercent);
  });

  test('mock: applying marks the offer as applied and a second time fails like the API',
      () async {
    final repository = MockJobRepository();
    expect((await repository.getJob('instadeep-ml')).dataOrNull?.hasApplied, isFalse);

    expect(await repository.apply('instadeep-ml'), isA<Success<void>>());
    expect((await repository.getJob('instadeep-ml')).dataOrNull?.hasApplied, isTrue);
    final list = (await repository.getJobs()).dataOrNull!;
    expect(list.firstWhere((j) => j.id == 'instadeep-ml').hasApplied, isTrue);

    final again = await repository.apply('instadeep-ml');
    expect(again, isA<Err<void>>());
    expect((again as Err<void>).failure.message, 'You already applied to this offer.');
  });
}
