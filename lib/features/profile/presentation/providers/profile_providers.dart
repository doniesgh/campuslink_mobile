import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/mock_profile_repository.dart';
import '../../domain/entities/student_profile.dart';
import '../../domain/repositories/profile_repository.dart';

/// Swap MockProfileRepository for the Dio-based implementation when the API is ready.
final profileRepositoryProvider =
    Provider<ProfileRepository>((ref) => MockProfileRepository());

final studentProfileProvider = FutureProvider.autoDispose<StudentProfile>(
  (ref) async => (await ref.watch(profileRepositoryProvider).getMyProfile()).unwrap(),
);
