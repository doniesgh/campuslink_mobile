import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/repositories/job_repository_impl.dart';
import '../../data/repositories/mock_job_repository.dart';
import '../../domain/entities/job.dart';
import '../../domain/entities/job_summary.dart';
import '../../domain/repositories/job_repository.dart';

/// Mock data with USE_MOCK=true, the Node.js API otherwise.
final jobRepositoryProvider = Provider<JobRepository>((ref) {
  return Env.useMock ? MockJobRepository() : JobRepositoryImpl(ref.watch(dioProvider));
});

/// Reloads when another user signs in (`hasApplied` and `canEdit` are theirs).
final jobsProvider = FutureProvider.autoDispose<List<Job>>((ref) async {
  ref.watch(currentUserIdProvider);
  return (await ref.watch(jobRepositoryProvider).getJobs()).unwrap();
});

final jobDetailProvider = FutureProvider.autoDispose.family<Job, String>(
  (ref, id) async => (await ref.watch(jobRepositoryProvider).getJob(id)).unwrap(),
);

/// The AI summary of an offer, asked once per opening of the summary sheet
/// (the server caches it). Invalidate it to ask again.
final jobSummaryProvider = FutureProvider.autoDispose.family<JobSummary, String>(
  (ref, id) async => (await ref.watch(jobRepositoryProvider).summarize(id)).unwrap(),
);

/// The signed-in user's role, null while signed out.
final jobsRoleProvider = Provider<UserRole?>(
  (ref) => ref.watch(authControllerProvider.select((auth) => auth.valueOrNull?.role)),
);

/// Companies and admins post offers ("New offer" on the Jobs tab). The API
/// checks again.
final canPostJobsProvider = Provider<bool>((ref) {
  final role = ref.watch(jobsRoleProvider);
  return role == UserRole.company || role == UserRole.admin;
});

/// Only students apply to offers, as in the PWA. The API checks again.
/// Null (no account loaded, e.g. in widget tests) keeps the button.
final canApplyToJobsProvider = Provider<bool>((ref) {
  final role = ref.watch(jobsRoleProvider);
  return role == null || role == UserRole.student;
});
