import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/mock_job_repository.dart';
import '../../domain/entities/job.dart';
import '../../domain/repositories/job_repository.dart';

final jobRepositoryProvider = Provider<JobRepository>((ref) => MockJobRepository());

final jobsProvider = FutureProvider.autoDispose<List<Job>>(
  (ref) async => (await ref.watch(jobRepositoryProvider).getJobs()).unwrap(),
);

final jobDetailProvider = FutureProvider.autoDispose.family<Job, String>(
  (ref, id) async => (await ref.watch(jobRepositoryProvider).getJob(id)).unwrap(),
);
