import '../academic_calendar.dart';

/// Academic data of the signed-in student (shown on the Profile tab and the
/// digital student ID). Name and email come from the auth [User].
class StudentProfile {
  const StudentProfile({
    required this.studentId,
    required this.program,
    required this.programShort,
    required this.className,
    required this.campus,
    required this.campusLocation,
    required this.semester,
    required this.academicYearStart,
    required this.validUntil,
    required this.ectsCredits,
    required this.gpa,
    required this.rankTopPercent,
    required this.promoYear,
    this.honours,
    this.isOnCampus = false,
    this.isVerified = false,
    this.nfcReady = false,
    this.hasEspritKey = false,
    this.unreadNotifications = 0,
    this.hasCarpoolActivity = false,
  });

  /// ENT / student number, e.g. "211JMT0428".
  final String studentId;

  /// "Software Engineering"
  final String program;

  /// Short form printed on the card: "Software Eng."
  final String programShort;

  /// "4BI"
  final String className;

  /// "ESPRIT Ghazela"
  final String campus;

  /// Where the "on campus" indicator points: "Ghazela Technopark".
  final String campusLocation;

  /// Overall semester number (S1..S10).
  final int semester;

  /// 2024 for the 2024–2025 academic year.
  final int academicYearStart;

  /// Last day the student card is valid.
  final DateTime validUntil;

  final int ectsCredits;
  final double gpa;

  /// "Top 5%" -> 5.
  final int rankTopPercent;

  /// Cohort year ("Promo 2025").
  final int promoYear;

  /// "Dean's List"
  final String? honours;

  final bool isOnCampus;

  /// ID checked by the school administration ("Verified ESPRIT").
  final bool isVerified;
  final bool nfcReady;
  final bool hasEspritKey;

  // TODO: read these two from the notifications / carpooling features once
  // they have repositories, instead of the profile payload.
  final int unreadNotifications;
  final bool hasCarpoolActivity;

  /// "Software Engineering (4BI) · ESPRIT Ghazela"
  String get programLine => '$program ($className) · $campus';

  /// "Software Eng. · Sem 8"
  String get cardProgramLine => '$programShort · Sem $semester';

  /// "S8"
  String get semesterLabel => 'S$semester';

  /// "2024–2025"
  String get academicYearLabel => formatAcademicYear(academicYearStart);

  /// "3.72"
  String get gpaLabel => gpa.toStringAsFixed(2);

  /// "Top 5%"
  String get rankLabel => 'Top $rankTopPercent%';

  /// "Promo 2025"
  String get promoLabel => 'Promo $promoYear';

  /// True until the end of the [validUntil] day.
  bool isValidOn(DateTime now) =>
      !DateTime(now.year, now.month, now.day).isAfter(
        DateTime(validUntil.year, validUntil.month, validUntil.day),
      );
}
