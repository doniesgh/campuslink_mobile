import '../../domain/entities/academic_transcript.dart';

/// Backend JSON of GET /grades/transcript (see backend/src/modules/grades).
///
/// Only raw marks are sent: averages, mentions and credits are computed by
/// `grading.dart`, as with the mock.
///
/// {
///   "studentId": "211JMT0428",   // null when no ENT ID is assigned yet
///   "semesters": [               // most recent first
///     {
///       "id": "2025-2026-s6", "academicYear": "2025–2026", "number": 6,
///       "updatedAt": "2026-11-05T07:00:00.000Z",
///       "rank": 7, "cohortSize": 142, "signedBy": "Dean Marc Lefèvre",
///       "documentSizeMb": 1.4,
///       "courses": [
///         { "code": "CS-401", "title": "...", "coefficient": 3, "credits": 10,
///           "continuous": 17.5, "exam": 16 }
///       ]
///     }
///   ]
/// }
class AcademicTranscriptModel {
  const AcademicTranscriptModel({required this.studentId, required this.semesters});

  factory AcademicTranscriptModel.fromJson(Map<String, dynamic> json) =>
      AcademicTranscriptModel(
        studentId: (json['studentId'] as String?) ?? pendingStudentId,
        semesters: [
          for (final s in json['semesters'] as List<dynamic>)
            SemesterRecordModel.fromJson(s as Map<String, dynamic>),
        ],
      );

  /// Shown instead of the ENT ID until the school assigns one.
  static const pendingStudentId = 'Pending';

  final String studentId;
  final List<SemesterRecordModel> semesters;

  AcademicTranscript toEntity() => AcademicTranscript(
        studentId: studentId,
        semesters: [for (final s in semesters) s.toEntity()],
      );
}

class SemesterRecordModel {
  const SemesterRecordModel({
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

  factory SemesterRecordModel.fromJson(Map<String, dynamic> json) => SemesterRecordModel(
        id: json['id'] as String,
        academicYear: json['academicYear'] as String,
        number: (json['number'] as num).toInt(),
        courses: [
          for (final c in json['courses'] as List<dynamic>)
            CourseGradeModel.fromJson(c as Map<String, dynamic>),
        ],
        updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
        rank: (json['rank'] as num?)?.toInt(),
        cohortSize: (json['cohortSize'] as num?)?.toInt(),
        signedBy: json['signedBy'] as String?,
        documentSizeMb: (json['documentSizeMb'] as num?)?.toDouble(),
      );

  final String id;
  final String academicYear;
  final int number;
  final List<CourseGradeModel> courses;
  final DateTime updatedAt;
  final int? rank;
  final int? cohortSize;
  final String? signedBy;
  final double? documentSizeMb;

  SemesterRecord toEntity() => SemesterRecord(
        id: id,
        academicYear: academicYear,
        number: number,
        courses: [for (final c in courses) c.toEntity()],
        updatedAt: updatedAt,
        rank: rank,
        cohortSize: cohortSize,
        signedBy: signedBy,
        documentSizeMb: documentSizeMb,
      );
}

class CourseGradeModel {
  const CourseGradeModel({
    required this.code,
    required this.title,
    required this.coefficient,
    required this.credits,
    this.continuous,
    this.exam,
  });

  factory CourseGradeModel.fromJson(Map<String, dynamic> json) => CourseGradeModel(
        code: json['code'] as String,
        title: json['title'] as String,
        coefficient: (json['coefficient'] as num).toDouble(),
        credits: (json['credits'] as num).toInt(),
        continuous: (json['continuous'] as num?)?.toDouble(),
        exam: (json['exam'] as num?)?.toDouble(),
      );

  final String code;
  final String title;
  final double coefficient;
  final int credits;
  final double? continuous;
  final double? exam;

  CourseGrade toEntity() => CourseGrade(
        code: code,
        title: title,
        coefficient: coefficient,
        credits: credits,
        continuous: continuous,
        exam: exam,
      );
}
