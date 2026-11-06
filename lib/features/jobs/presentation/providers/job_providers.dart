import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/repositories/job_repository_impl.dart';
import '../../data/repositories/mock_job_repository.dart';
import '../../domain/entities/job.dart';
import '../../domain/repositories/job_repository.dart';

/// Mock data with USE_MOCK=true, the Node.js API otherwise.
final jobRepositoryProvider = Provider<JobRepository>((ref) {
  return Env.useMock ? MockJobRepository() : JobRepositoryImpl(ref.watch(dioProvider));
});

final jobsProvider = FutureProvider.autoDispose<List<Job>>(
  (ref) async => (await ref.watch(jobRepositoryProvider).getJobs()).unwrap(),
);

final jobDetailProvider = FutureProvider.autoDispose.family<Job, String>(
  (ref, id) async => (await ref.watch(jobRepositoryProvider).getJob(id)).unwrap(),
);
