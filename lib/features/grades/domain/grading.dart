import 'entities/academic_transcript.dart';

/// Grading rules of the Tunisian system: marks out of 20, coefficient-weighted
/// averages, a course/semester is validated at ≥ 10/20.
///
/// Everything here is pure Dart (no Flutter) and unit-tested.
abstract final class GradingRules {
  static const double maxMark = 20;
  static const double passMark = 10;

  /// Course average = 40% continuous assessment + 60% final exam
  /// (matches the design: 17.5 / 16.0 → 16.60).
  static const double continuousWeight = 0.4;
  static const double examWeight = 0.6;

  /// Minimum average for the honor roll ("tableau d'honneur").
  static const double honorRollMark = 14;
}

/// Tunisian mention, from an average out of 20.
enum Mention {
  tresBien('Très Bien', 'Excellent', 16),
  bien('Bien', 'Very Good', 14),
  assezBien('Assez Bien', 'Good', 12),
  passable('Passable', 'Satisfactory', 10),
  ajourne('Ajourné', 'Insufficient', double.negativeInfinity);

  const Mention(this.label, this.standing, this.minAverage);

  /// French label as printed on the transcript ("Très Bien").
  final String label;

  /// English standing shown in the hero card ("Excellent").
  final String standing;

  /// Lowest average (inclusive) giving this mention.
  final double minAverage;

  bool get isPassing => this != Mention.ajourne;
}

enum CourseStatus {
  /// Average ≥ 10/20: credits earned.
  validated,

  /// Average < 10/20 in a validated semester: credits earned by compensation.
  compensated,

  /// Average < 10/20 in a semester that is not validated: no credits.
  failed,

  /// No mark published yet.
  pending,
}

/// Rounds a mark to 2 decimals, half away from zero (12.345 → 12.35).
/// The tiny epsilon absorbs binary floating-point noise (12.345 is stored as
/// 12.3449999…).
double roundGrade(double value) {
  final scaled = value * 100;
  return (scaled + (scaled >= 0 ? 1e-6 : -1e-6)).round() / 100;
}

/// Final average of a course, rounded to 2 decimals.
/// Uses the 40/60 weighting when both marks exist, otherwise the only mark
/// available (e.g. language courses without a final exam). Null if no mark.
double? courseAverage({double? continuous, double? exam}) {
  if (continuous != null && exam != null) {
    return roundGrade(
      continuous * GradingRules.continuousWeight + exam * GradingRules.examWeight,
    );
  }
  final only = continuous ?? exam;
  return only == null ? null : roundGrade(only);
}

/// Σ(mark × weight) / Σ(weight), rounded to 2 decimals. Null if the total
/// weight is zero (nothing graded).
double? weightedAverage(Iterable<(double mark, double weight)> marks) {
  var sum = 0.0;
  var weights = 0.0;
  for (final (mark, weight) in marks) {
    sum += mark * weight;
    weights += weight;
  }
  return weights <= 0 ? null : roundGrade(sum / weights);
}

/// True when a (rounded) average validates the course or semester.
bool isPassing(double average) => average >= GradingRules.passMark;

/// Mention for a (rounded) average.
Mention mentionFor(double average) =>
    Mention.values.firstWhere((m) => average >= m.minAverage);

/// Letter grade shown next to "Validé": A+ ≥ 18, A ≥ 16, B+ ≥ 14, B ≥ 12,
/// C ≥ 10, D ≥ 8, F below.
String letterGrade(double average) => switch (average) {
      >= 18 => 'A+',
      >= 16 => 'A',
      >= 14 => 'B+',
      >= 12 => 'B',
      >= 10 => 'C',
      >= 8 => 'D',
      _ => 'F',
    };

/// "Top X%" of the cohort, rounded up (rank 7 of 142 → 5).
int topPercent(int rank, int cohortSize) {
  assert(rank >= 1 && cohortSize >= rank, 'Invalid rank $rank/$cohortSize');
  return (rank * 100 + cohortSize - 1) ~/ cohortSize;
}

/// Coefficient-weighted average of the graded courses of [semester], computed
/// from the rounded course averages (as printed on the transcript).
double? semesterAverage(SemesterRecord semester) => weightedAverage([
      for (final c in semester.courses)
        if (courseAverage(continuous: c.continuous, exam: c.exam) case final avg?)
          (avg, c.coefficient),
    ]);

/// Computed result of one course.
class CourseResult {
  const CourseResult({
    required this.course,
    required this.average,
    required this.status,
    required this.creditsEarned,
  });

  final CourseGrade course;

  /// Final average out of 20, rounded to 2 decimals. Null while pending.
  final double? average;
  final CourseStatus status;
  final int creditsEarned;

  /// Letter grade ("A+"), null while pending.
  String? get letter => average == null ? null : letterGrade(average!);

  /// 0–1 share of the maximum mark, for progress bars.
  double get progress =>
      ((average ?? 0) / GradingRules.maxMark).clamp(0.0, 1.0).toDouble();
}

/// Computed result of a semester.
class SemesterResult {
  const SemesterResult({
    required this.semester,
    required this.courses,
    required this.average,
    required this.creditsEarned,
    required this.creditsTotal,
    this.previousAverage,
  });

  final SemesterRecord semester;
  final List<CourseResult> courses;

  /// Coefficient-weighted average of the graded courses, rounded to 2
  /// decimals. Null when nothing is graded yet.
  final double? average;
  final int creditsEarned;
  final int creditsTotal;

  /// Average of the previous semester, for the trend pill.
  final double? previousAverage;

  /// Every course has a mark.
  bool get isComplete => courses.every((c) => c.status != CourseStatus.pending);

  /// Complete semester with an average ≥ 10/20.
  bool get isValidated => isComplete && average != null && isPassing(average!);

  Mention? get mention => average == null ? null : mentionFor(average!);

  /// The average as a percentage of 20 (16.57 → 83).
  int? get scorePercent =>
      average == null ? null : (average! / GradingRules.maxMark * 100).round();

  /// Change since the previous semester, in points.
  double? get delta {
    final a = average, p = previousAverage;
    return a == null || p == null ? null : roundGrade(a - p);
  }

  /// Honor roll: complete semester, average ≥ 14/20 and every course
  /// validated on its own (no compensation).
  bool get isHonorRoll =>
      isComplete &&
      average != null &&
      average! >= GradingRules.honorRollMark &&
      courses.every((c) => c.status == CourseStatus.validated);

  /// "Top X%" of the cohort, when the rank is published.
  int? get topCohortPercent {
    final rank = semester.rank, size = semester.cohortSize;
    if (rank == null || size == null || size <= 0 || rank < 1 || rank > size) {
      return null;
    }
    return topPercent(rank, size);
  }
}

/// Computes averages, statuses and credits of [semester].
///
/// A course below 10/20 is compensated (its credits are earned) when the
/// semester itself is validated; otherwise it is failed.
SemesterResult evaluateSemester(SemesterRecord semester, {SemesterRecord? previous}) {
  final averages = [
    for (final c in semester.courses) courseAverage(continuous: c.continuous, exam: c.exam),
  ];
  final average = semesterAverage(semester);
  final complete = averages.every((a) => a != null);
  final validated = complete && average != null && isPassing(average);

  final courses = <CourseResult>[];
  for (var i = 0; i < semester.courses.length; i++) {
    final course = semester.courses[i];
    final avg = averages[i];
    final status = avg == null
        ? CourseStatus.pending
        : isPassing(avg)
            ? CourseStatus.validated
            : validated
                ? CourseStatus.compensated
                : CourseStatus.failed;
    final earned = status == CourseStatus.validated || status == CourseStatus.compensated;
    courses.add(CourseResult(
      course: course,
      average: avg,
      status: status,
      creditsEarned: earned ? course.credits : 0,
    ));
  }

  return SemesterResult(
    semester: semester,
    courses: courses,
    average: average,
    creditsEarned: courses.fold(0, (sum, c) => sum + c.creditsEarned),
    creditsTotal: semester.courses.fold(0, (sum, c) => sum + c.credits),
    previousAverage: previous == null ? null : semesterAverage(previous),
  );
}

/// Result of the semester [semesterId] of [transcript] (the most recent one
/// when null or unknown), compared with the semester just before it.
/// Null when no semester is published.
SemesterResult? semesterResultFor(AcademicTranscript transcript, String? semesterId) {
  final semesters = transcript.semesters;
  if (semesters.isEmpty) return null;
  final found = semesters.indexWhere((s) => s.id == semesterId);
  final i = found < 0 ? 0 : found;
  return evaluateSemester(
    semesters[i],
    previous: i + 1 < semesters.length ? semesters[i + 1] : null,
  );
}
