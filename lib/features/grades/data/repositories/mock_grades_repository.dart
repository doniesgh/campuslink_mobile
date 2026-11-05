import '../../../../core/error/result.dart';
import '../../domain/entities/academic_transcript.dart';
import '../../domain/repositories/grades_repository.dart';

/// In-memory fake. Replace with a Dio-based implementation when the API exists.
///
/// The student is in their 4th year, like on the Profile screen. The three
/// published semesters are the three before the current one, so their numbers,
/// academic years and dates follow [clock] (in November 2026, current S7:
/// Sem 6 and Sem 5 of 2025–2026, Sem 4 of 2024–2025).
///
/// Only raw marks are stored; every average shown on screen is computed from
/// them: latest semester → 16.57 (+0.35 since the one before, 16.22), oldest →
/// 12.29 with one compensated course.
class MockGradesRepository implements GradesRepository {
  MockGradesRepository({
    this.latency = const Duration(milliseconds: 400),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration latency;
  final DateTime Function() _clock;

  static const _studentId = 'CP-2024-8891';
  static const _dean = 'Dean Marc Lefèvre';
  static const _yearOfStudy = 4;

  /// Marks of the published semesters, latest first.
  static const _published = [
    // The design's "Sem 8" content.
    _SemesterMarks(
      rank: 7,
      cohortSize: 142,
      documentSizeMb: 1.4,
      courses: [
        CourseGrade(
          code: 'CS-401',
          title: 'Génie Logiciel & Microservices',
          coefficient: 3,
          credits: 10,
          continuous: 17.5,
          exam: 16,
        ),
        CourseGrade(
          code: 'DB-408',
          title: 'Conception & BDD NoSQL',
          coefficient: 2.5,
          credits: 8,
          continuous: 18,
          exam: 15.5,
        ),
        CourseGrade(
          code: 'SEC-402',
          title: 'Réseaux & Sécurité Informatique',
          coefficient: 2,
          credits: 7,
          continuous: 14.5,
          exam: 15,
        ),
        // Language course: continuous assessment only, no final exam.
        CourseGrade(
          code: 'HUM-304',
          title: 'Anglais Pro & Soft Skills',
          coefficient: 1.5,
          credits: 5,
          continuous: 19,
        ),
      ],
    ),
    // Same course names as the timetable.
    _SemesterMarks(
      rank: 11,
      cohortSize: 142,
      documentSizeMb: 1.3,
      courses: [
        CourseGrade(
          code: 'CS-305',
          title: 'Algorithmes & Complexité',
          coefficient: 3,
          credits: 10,
          continuous: 16,
          exam: 15.5,
        ),
        CourseGrade(
          code: 'CS-307',
          title: 'Génie Logiciel & Architecture',
          coefficient: 2.5,
          credits: 8,
          continuous: 17,
          exam: 16.5,
        ),
        CourseGrade(
          code: 'DB-306',
          title: 'Bases de Données',
          coefficient: 2,
          credits: 7,
          continuous: 15.5,
          exam: 16,
        ),
        CourseGrade(
          code: 'MATH-302',
          title: 'Probabilités & Statistiques',
          coefficient: 1.5,
          credits: 5,
          continuous: 17,
          exam: 17,
        ),
      ],
    ),
    _SemesterMarks(
      rank: 48,
      cohortSize: 140,
      documentSizeMb: 1.2,
      courses: [
        CourseGrade(
          code: 'CS-301',
          title: 'Programmation Orientée Objet',
          coefficient: 3,
          credits: 10,
          continuous: 14,
          exam: 13,
        ),
        // 9.10/20, compensated by the semester average.
        CourseGrade(
          code: 'MATH-303',
          title: 'Analyse Numérique',
          coefficient: 2.5,
          credits: 8,
          continuous: 10,
          exam: 8.5,
        ),
        CourseGrade(
          code: 'SYS-304',
          title: "Systèmes d'Exploitation",
          coefficient: 2,
          credits: 7,
          continuous: 13.5,
          exam: 12,
        ),
        CourseGrade(
          code: 'HUM-204',
          title: 'Français & Communication',
          coefficient: 1.5,
          credits: 5,
          continuous: 15,
        ),
      ],
    ),
  ];

  @override
  Future<Result<AcademicTranscript>> getTranscript() async {
    await Future<void>.delayed(latency);
    final now = _clock();
    final current = _semesterFor(_yearOfStudy, now);
    final currentStart = _academicYearStartFor(now);
    return Success(
      AcademicTranscript(
        studentId: _studentId,
        semesters: [
          for (var i = 0; i < _published.length; i++)
            _published[i].toRecord(
              number: current - 1 - i,
              currentYearStart: currentStart,
              updatedAt: i == 0 ? now.subtract(const Duration(hours: 2)) : null,
            ),
        ],
      ),
    );
  }

  // Calendar helpers mirroring lib/features/profile/domain/academic_calendar.dart
  // (duplicated to keep features independent): the academic year starts in
  // September, odd semesters run September–January, even ones February–August.

  /// Start year of the academic year containing [date] (Nov 2026 → 2026,
  /// Mar 2027 → 2026).
  static int _academicYearStartFor(DateTime date) =>
      date.month >= DateTime.september ? date.year : date.year - 1;

  /// Overall semester number of a student in [yearOfStudy] on [date]
  /// (4th year: S7 in the fall, S8 in the spring).
  static int _semesterFor(int yearOfStudy, DateTime date) {
    final spring = date.month >= DateTime.february && date.month < DateTime.september;
    return (yearOfStudy - 1) * 2 + (spring ? 2 : 1);
  }
}

class _SemesterMarks {
  const _SemesterMarks({
    required this.rank,
    required this.cohortSize,
    required this.documentSizeMb,
    required this.courses,
  });

  final int rank;
  final int cohortSize;
  final double documentSizeMb;
  final List<CourseGrade> courses;

  /// Semester [number] of a 4th-year student whose current academic year
  /// starts in [currentYearStart]. Without [updatedAt], results are dated when
  /// they are usually published: ~7 February for a fall semester, ~3 July for
  /// a spring one.
  SemesterRecord toRecord({
    required int number,
    required int currentYearStart,
    DateTime? updatedAt,
  }) {
    final yearOfStudy = (number + 1) ~/ 2;
    final start =
        currentYearStart - (MockGradesRepository._yearOfStudy - yearOfStudy);
    final fall = number.isOdd;
    return SemesterRecord(
      id: '$start-${start + 1}-s$number',
      academicYear: '$start–${start + 1}',
      number: number,
      updatedAt: updatedAt ??
          (fall ? DateTime(start + 1, 2, 7, 14, 30) : DateTime(start + 1, 7, 3, 10)),
      rank: rank,
      cohortSize: cohortSize,
      signedBy: MockGradesRepository._dean,
      documentSizeMb: documentSizeMb,
      courses: courses,
    );
  }
}
