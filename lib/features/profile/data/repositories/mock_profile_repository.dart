import '../../../../core/error/result.dart';
import '../../domain/academic_calendar.dart';
import '../../domain/entities/student_profile.dart';
import '../../domain/repositories/profile_repository.dart';

/// In-memory fake. Replace with a Dio-based implementation when the API exists.
///
/// The academic year, semester and card validity follow [clock] so the card
/// never looks expired in demos.
class MockProfileRepository implements ProfileRepository {
  MockProfileRepository({
    this.latency = const Duration(milliseconds: 400),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration latency;
  final DateTime Function() _clock;

  static const _yearOfStudy = 4;

  @override
  Future<Result<StudentProfile>> getMyProfile() async {
    await Future<void>.delayed(latency);
    final now = _clock();
    final yearStart = academicYearStartFor(now);
    return Success(
      StudentProfile(
        studentId: '211JMT0428',
        program: 'Software Engineering',
        programShort: 'Software Eng.',
        className: '${_yearOfStudy}BI',
        campus: 'ESPRIT Ghazela',
        campusLocation: 'Ghazela Technopark',
        semester: semesterFor(_yearOfStudy, now),
        academicYearStart: yearStart,
        validUntil: cardValidUntil(yearStart),
        ectsCredits: 94,
        gpa: 3.72,
        honours: "Dean's List",
        rankTopPercent: 5,
        promoYear: yearStart + 1,
        isOnCampus: true,
        isVerified: true,
        nfcReady: true,
        hasEspritKey: true,
        unreadNotifications: 3,
        hasCarpoolActivity: true,
      ),
    );
  }
}
