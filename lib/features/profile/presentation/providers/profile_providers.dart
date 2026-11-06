import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/repositories/mock_profile_repository.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/student_profile.dart';
import '../../domain/repositories/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return Env.useMock
      ? MockProfileRepository()
      : ProfileRepositoryImpl(ref.watch(dioProvider));
});

final studentProfileProvider = FutureProvider.autoDispose<StudentProfile>(
  (ref) async => (await ref.watch(profileRepositoryProvider).getMyProfile()).unwrap(),
);
