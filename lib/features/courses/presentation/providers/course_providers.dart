import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/mock_course_repository.dart';
import '../../domain/entities/course.dart';
import '../../domain/repositories/course_repository.dart';

/// Swap MockCourseRepository for the Dio-based implementation when the API is ready.
final courseRepositoryProvider =
    Provider<CourseRepository>((ref) => MockCourseRepository());

final coursesProvider = FutureProvider.autoDispose<List<Course>>(
  (ref) async => (await ref.watch(courseRepositoryProvider).getCourses()).unwrap(),
);
