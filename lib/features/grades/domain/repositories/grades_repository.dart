import '../../../../core/error/result.dart';
import '../entities/academic_transcript.dart';

abstract interface class GradesRepository {
  /// The student's published semesters, most recent first.
  Future<Result<AcademicTranscript>> getTranscript();
}
