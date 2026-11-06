import 'package:dio/dio.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/course.dart';
import '../../domain/repositories/course_repository.dart';
import '../models/course_models.dart';

/// Courses from the Node.js API. Attendance and submissions are stored per
/// student on the server; its error messages are shown as-is.
class CourseRepositoryImpl implements CourseRepository {
  const CourseRepositoryImpl(this._dio);
  final Dio _dio;

  @override
  Future<Result<List<Course>>> getCourses() => guard(() async {
        final r = await _dio.get<dynamic>(ApiEndpoints.courses);
        return [for (final c in r.data as List) courseFromJson(c as Map<String, dynamic>)];
      });

  @override
  Future<Result<void>> setAttendance(String courseId, {required bool present}) => guard(() async {
        await _dio.put<void>(ApiEndpoints.courseAttendance(courseId), data: {'present': present});
      });

  /// The server answers with the file's link (`{ "url": ... }`); saving the
  /// file for offline reading is not done yet.
  @override
  Future<Result<void>> downloadResource(String resourceId) => guard(() async {
        await _dio.post<dynamic>(ApiEndpoints.courseResourceDownload(resourceId));
      });

  @override
  Future<Result<void>> submitAssignment(String assignmentId, String repoUrl) => guard(() async {
        await _dio.post<dynamic>(
          ApiEndpoints.courseAssignmentSubmission(assignmentId),
          data: {'repoUrl': repoUrl.trim()},
        );
      });
}
