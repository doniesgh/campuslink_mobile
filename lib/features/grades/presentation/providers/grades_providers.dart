import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/mock_grades_repository.dart';
import '../../domain/entities/academic_transcript.dart';
import '../../domain/repositories/grades_repository.dart';

/// Swap MockGradesRepository for the Dio-based implementation when the API is ready.
final gradesRepositoryProvider =
    Provider<GradesRepository>((ref) => MockGradesRepository());

final transcriptProvider = FutureProvider.autoDispose<AcademicTranscript>(
  (ref) async => (await ref.watch(gradesRepositoryProvider).getTranscript()).unwrap(),
);

/// Semester picked in the period selector; null means the most recent one.
final selectedSemesterIdProvider = StateProvider.autoDispose<String?>((ref) => null);
