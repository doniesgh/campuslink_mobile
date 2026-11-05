/// One course (module) of a semester, with its raw marks out of 20.
///
/// Averages, validation and credits are never stored: they are computed by
/// the pure functions of `grading.dart` so the screen always stays consistent
/// with the marks.
class CourseGrade {
  const CourseGrade({
    required this.code,
    required this.title,
    required this.coefficient,
    required this.credits,
    this.continuous,
    this.exam,
  });

  /// e.g. "CS-401"
  final String code;
  final String title;

  /// Weight of the course in the semester average (e.g. 3.0).
  final double coefficient;

  /// ECTS credits earned when the course is validated.
  final int credits;

  /// Continuous assessment mark (contrôle continu), out of 20. Null if none.
  final double? continuous;

  /// Final exam mark, out of 20. Null if the course has no exam or it is not
  /// graded yet.
  final double? exam;
}

/// The marks of one semester.
class SemesterRecord {
  const SemesterRecord({
    required this.id,
    required this.academicYear,
    required this.number,
    required this.courses,
    required this.updatedAt,
    this.rank,
    this.cohortSize,
    this.signedBy,
    this.documentSizeMb,
  });

  final String id;

  /// e.g. "2024–2025"
  final String academicYear;

  /// Semester number in the curriculum (e.g. 8).
  final int number;
  final List<CourseGrade> courses;

  /// When the marks were last published.
  final DateTime updatedAt;

  /// Position in the cohort (1 = best), when published.
  final int? rank;
  final int? cohortSize;

  /// Who signed the official record (e.g. "Dean Marc Lefèvre"). Null while the
  /// results are provisional.
  final String? signedBy;

  /// Size of the signed PDF transcript, when available.
  final double? documentSizeMb;

  /// "2024–2025 · Sem 8"
  String get label => '$academicYear · Sem $number';

  bool get isOfficial => signedBy != null;
}

/// All the published semesters of the student.
class AcademicTranscript {
  const AcademicTranscript({required this.studentId, required this.semesters});

  /// e.g. "CP-2024-8891"
  final String studentId;

  /// Most recent first.
  final List<SemesterRecord> semesters;
}
