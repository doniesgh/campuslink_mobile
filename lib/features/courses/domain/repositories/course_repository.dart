import '../../../../core/error/result.dart';
import '../entities/course.dart';

abstract interface class CourseRepository {
  /// Courses the student is enrolled in this semester.
  Future<Result<List<Course>>> getCourses();

  /// Logs (or undoes) the student's attendance for the latest session.
  Future<Result<void>> setAttendance(String courseId, {required bool present});

  /// Downloads a document for offline reading.
  Future<Result<void>> downloadResource(String resourceId);

  /// Hands in a lab as a repository link.
  Future<Result<void>> submitAssignment(String assignmentId, String repoUrl);
}
