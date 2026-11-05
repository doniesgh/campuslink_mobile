import '../../../../core/error/result.dart';
import '../entities/student_profile.dart';

abstract interface class ProfileRepository {
  /// Academic profile of the signed-in student.
  Future<Result<StudentProfile>> getMyProfile();
}
