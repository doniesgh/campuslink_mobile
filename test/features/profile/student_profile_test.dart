import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/features/profile/data/repositories/mock_profile_repository.dart';
import 'package:campuspulse/features/profile/domain/academic_calendar.dart';
import 'package:campuspulse/features/profile/domain/entities/student_profile.dart';
import 'package:campuspulse/features/profile/presentation/utils/initials.dart';
import 'package:flutter_test/flutter_test.dart';

StudentProfile _profile({DateTime? validUntil}) => StudentProfile(
      studentId: '211JMT0428',
      program: 'Software Engineering',
      programShort: 'Software Eng.',
      className: '4BI',
      campus: 'ESPRIT Ghazela',
      campusLocation: 'Ghazela Technopark',
      semester: 8,
      academicYearStart: 2024,
      validUntil: validUntil ?? DateTime(2025, 9, 30),
      ectsCredits: 94,
      gpa: 3.7,
      rankTopPercent: 5,
      promoYear: 2025,
      honours: "Dean's List",
    );

void main() {
  group('academic calendar', () {
    test('academic year starts in September', () {
      expect(academicYearStartFor(DateTime(2026, 11, 5)), 2026);
      expect(academicYearStartFor(DateTime(2026, 9, 1)), 2026);
      expect(academicYearStartFor(DateTime(2026, 8, 31)), 2025);
      expect(academicYearStartFor(DateTime(2027, 1, 10)), 2026);
    });

    test('formats the academic year with an en dash', () {
      expect(formatAcademicYear(2024), '2024–2025');
    });

    test('semester number from year of study and date', () {
      expect(semesterFor(4, DateTime(2026, 11, 5)), 7);
      expect(semesterFor(4, DateTime(2027, 1, 31)), 7);
      expect(semesterFor(4, DateTime(2027, 2, 1)), 8);
      expect(semesterFor(4, DateTime(2027, 8, 31)), 8);
      expect(semesterFor(1, DateTime(2026, 9, 20)), 1);
      expect(() => semesterFor(0, DateTime(2026, 9, 20)), throwsArgumentError);
    });

    test('cards are valid until 30 September of the following year', () {
      expect(cardValidUntil(2024), DateTime(2025, 9, 30));
    });
  });

  group('StudentProfile', () {
    final p = _profile();

    test('display labels', () {
      expect(p.programLine, 'Software Engineering (4BI) · ESPRIT Ghazela');
      expect(p.cardProgramLine, 'Software Eng. · Sem 8');
      expect(p.semesterLabel, 'S8');
      expect(p.academicYearLabel, '2024–2025');
      expect(p.gpaLabel, '3.70');
      expect(p.rankLabel, 'Top 5%');
      expect(p.promoLabel, 'Promo 2025');
    });

    test('is valid through the whole last day', () {
      expect(p.isValidOn(DateTime(2025, 1, 1)), isTrue);
      expect(p.isValidOn(DateTime(2025, 9, 30, 23, 59)), isTrue);
      expect(p.isValidOn(DateTime(2025, 10, 1)), isFalse);
    });
  });

  group('initialsOf', () {
    test('uses the first two words', () {
      expect(initialsOf('Dony Ben Salem'), 'DB');
      expect(initialsOf('  amira   trabelsi '), 'AT');
      expect(initialsOf('dony'), 'D');
      expect(initialsOf('   '), '?');
    });
  });

  group('MockProfileRepository', () {
    test('follows the clock for the year, semester and validity', () async {
      final now = DateTime(2026, 11, 5);
      final repo = MockProfileRepository(latency: Duration.zero, clock: () => now);
      final result = await repo.getMyProfile();
      expect(result, isA<Success<StudentProfile>>());
      final profile = result.unwrap();
      expect(profile.studentId, '211JMT0428');
      expect(profile.academicYearLabel, '2026–2027');
      expect(profile.semesterLabel, 'S7');
      expect(profile.isValidOn(now), isTrue);
    });
  });
}
