import '../../domain/entities/student_profile.dart';

/// Backend JSON of GET /profile (see backend/src/modules/profile).
///
/// The semester, academic year and card validity are computed by the server
/// from the request date, with the rules of `academic_calendar.dart`.
///
/// {
///   "studentId": "211JMT0428",          // null when no ENT ID is assigned yet
///   "displayName": "Dony Mansour", "email": "...",   // also on the auth User
///   "program": "Software Engineering", "programShort": "Software Eng.",
///   "className": "4BI", "yearOfStudy": 4,
///   "campus": "ESPRIT Ghazela", "campusLocation": "Ghazela Technopark",
///   "semester": 7, "academicYearStart": 2026, "validUntil": "2027-09-30",
///   "ectsCredits": 90, "gpa": 3.72, "rankTopPercent": 5, "promoYear": 2027,
///   "honours": "Dean's List",           // or null
///   "isOnCampus": true, "isVerified": true, "nfcReady": true,
///   "hasEspritKey": true, "unreadNotifications": 3, "hasCarpoolActivity": true
/// }
class StudentProfileModel {
  const StudentProfileModel({
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

  factory StudentProfileModel.fromJson(Map<String, dynamic> json) => StudentProfileModel(
        studentId: (json['studentId'] as String?) ?? pendingStudentId,
        program: json['program'] as String,
        programShort: json['programShort'] as String,
        className: json['className'] as String,
        campus: json['campus'] as String,
        campusLocation: json['campusLocation'] as String,
        semester: (json['semester'] as num).toInt(),
        academicYearStart: (json['academicYearStart'] as num).toInt(),
        // A calendar date ('YYYY-MM-DD'): parsed as local midnight, no time zone shift.
        validUntil: DateTime.parse(json['validUntil'] as String),
        ectsCredits: (json['ectsCredits'] as num).toInt(),
        gpa: (json['gpa'] as num).toDouble(),
        rankTopPercent: (json['rankTopPercent'] as num).toInt(),
        promoYear: (json['promoYear'] as num).toInt(),
        honours: json['honours'] as String?,
        isOnCampus: (json['isOnCampus'] as bool?) ?? false,
        isVerified: (json['isVerified'] as bool?) ?? false,
        nfcReady: (json['nfcReady'] as bool?) ?? false,
        hasEspritKey: (json['hasEspritKey'] as bool?) ?? false,
        unreadNotifications: (json['unreadNotifications'] as num?)?.toInt() ?? 0,
        hasCarpoolActivity: (json['hasCarpoolActivity'] as bool?) ?? false,
      );

  /// Shown instead of the ENT ID until the school assigns one.
  static const pendingStudentId = 'Pending';

  final String studentId;
  final String program;
  final String programShort;
  final String className;
  final String campus;
  final String campusLocation;
  final int semester;
  final int academicYearStart;
  final DateTime validUntil;
  final int ectsCredits;
  final double gpa;
  final int rankTopPercent;
  final int promoYear;
  final String? honours;
  final bool isOnCampus;
  final bool isVerified;
  final bool nfcReady;
  final bool hasEspritKey;
  final int unreadNotifications;
  final bool hasCarpoolActivity;

  StudentProfile toEntity() => StudentProfile(
        studentId: studentId,
        program: program,
        programShort: programShort,
        className: className,
        campus: campus,
        campusLocation: campusLocation,
        semester: semester,
        academicYearStart: academicYearStart,
        validUntil: validUntil,
        ectsCredits: ectsCredits,
        gpa: gpa,
        rankTopPercent: rankTopPercent,
        promoYear: promoYear,
        honours: honours,
        isOnCampus: isOnCampus,
        isVerified: isVerified,
        nfcReady: nfcReady,
        hasEspritKey: hasEspritKey,
        unreadNotifications: unreadNotifications,
        hasCarpoolActivity: hasCarpoolActivity,
      );
}
