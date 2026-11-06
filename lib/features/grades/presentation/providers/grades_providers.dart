import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/repositories/grades_repository_impl.dart';
import '../../data/repositories/mock_grades_repository.dart';
import '../../domain/entities/academic_transcript.dart';
import '../../domain/repositories/grades_repository.dart';

final gradesRepositoryProvider = Provider<GradesRepository>((ref) {
  return Env.useMock
      ? MockGradesRepository()
      : GradesRepositoryImpl(ref.watch(dioProvider));
});

final transcriptProvider = FutureProvider.autoDispose<AcademicTranscript>(
  (ref) async => (await ref.watch(gradesRepositoryProvider).getTranscript()).unwrap(),
);

/// Semester picked in the period selector; null means the most recent one.
final selectedSemesterIdProvider = StateProvider.autoDispose<String?>((ref) => null);
