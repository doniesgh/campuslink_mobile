/// Pure date helpers for the ESPRIT academic calendar (mock rules until the
/// backend exposes them): the year starts in September, semester 1 runs
/// September–January and semester 2 February–August.
library;

/// Start year of the academic year containing [date].
/// November 2026 -> 2026, March 2027 -> 2026.
int academicYearStartFor(DateTime date) =>
    date.month >= DateTime.september ? date.year : date.year - 1;

/// 2024 -> "2024–2025" (en dash, as printed on the student card).
String formatAcademicYear(int startYear) => '$startYear–${startYear + 1}';

/// Overall semester number of a student in [yearOfStudy] (1-based) on [date].
/// A 4th-year student is in S7 in the fall and S8 in the spring.
int semesterFor(int yearOfStudy, DateTime date) {
  if (yearOfStudy < 1) throw ArgumentError.value(yearOfStudy, 'yearOfStudy', 'must be >= 1');
  final spring = date.month >= DateTime.february && date.month < DateTime.september;
  return (yearOfStudy - 1) * 2 + (spring ? 2 : 1);
}

/// Student cards stay valid until 30 September after the academic year ends.
DateTime cardValidUntil(int academicYearStart) =>
    DateTime(academicYearStart + 1, DateTime.september, 30);
