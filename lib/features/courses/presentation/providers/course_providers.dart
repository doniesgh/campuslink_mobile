import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/repositories/course_repository_impl.dart';
import '../../data/repositories/mock_course_repository.dart';
import '../../domain/entities/course.dart';
import '../../domain/repositories/course_repository.dart';

/// The API (USE_MOCK=false) or the in-memory fake.
final courseRepositoryProvider = Provider<CourseRepository>((ref) {
  return Env.useMock ? MockCourseRepository() : CourseRepositoryImpl(ref.watch(dioProvider));
});

final coursesProvider = FutureProvider.autoDispose<List<Course>>(
  (ref) async => (await ref.watch(courseRepositoryProvider).getCourses()).unwrap(),
);
