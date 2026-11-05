import 'package:campuspulse/features/grades/domain/entities/academic_transcript.dart';
import 'package:campuspulse/features/grades/domain/grading.dart';
import 'package:flutter_test/flutter_test.dart';

SemesterRecord _semester(String id, List<CourseGrade> courses, {int number = 1}) =>
    SemesterRecord(
      id: id,
      academicYear: '2024–2025',
      number: number,
      courses: courses,
      updatedAt: DateTime(2025, 6, 30),
    );

CourseGrade _course(
  String code, {
  double coefficient = 1,
  int credits = 5,
  double? continuous,
  double? exam,
}) =>
    CourseGrade(
      code: code,
      title: code,
      coefficient: coefficient,
      credits: credits,
      continuous: continuous,
      exam: exam,
    );

void main() {
  group('roundGrade', () {
    test('rounds to 2 decimals, half away from zero', () {
      expect(roundGrade(16.572222), 16.57);
      expect(roundGrade(12.345), 12.35); // stored as 12.3449999…
      expect(roundGrade(9.994), 9.99);
      expect(roundGrade(9.995), 10.0);
      expect(roundGrade(-0.345), -0.35);
    });
  });

  group('courseAverage (40% continuous + 60% exam)', () {
    test('matches the design cards', () {
      expect(courseAverage(continuous: 17.5, exam: 16), 16.6); // 7.0 + 9.6
      expect(courseAverage(continuous: 18, exam: 15.5), 16.5); // 7.2 + 9.3
      expect(courseAverage(continuous: 14.5, exam: 15), 14.8); // 5.8 + 9.0
    });

    test('uses the only mark available', () {
      expect(courseAverage(continuous: 19), 19.0);
      expect(courseAverage(exam: 12.25), 12.25);
    });

    test('is null without any mark', () {
      expect(courseAverage(), isNull);
    });

    test('is rounded to 2 decimals', () {
      // 0.4 × 13.33 + 0.6 × 11.17 = 5.332 + 6.702 = 12.034
      expect(courseAverage(continuous: 13.33, exam: 11.17), 12.03);
    });
  });

  group('weightedAverage', () {
    test('Σ(mark × coefficient) / Σ(coefficient)', () {
      // (49.8 + 41.25 + 29.6 + 28.5) / 9 = 149.15 / 9 = 16.5722…
      expect(
        weightedAverage([(16.6, 3), (16.5, 2.5), (14.8, 2), (19, 1.5)]),
        16.57,
      );
      // (12 × 2 + 15 × 1) / 3 = 13
      expect(weightedAverage([(12, 2), (15, 1)]), 13.0);
    });

    test('is null when nothing is weighted', () {
      expect(weightedAverage(const []), isNull);
      expect(weightedAverage([(14, 0)]), isNull);
    });
  });

  test('isPassing: validated at 10/20', () {
    expect(isPassing(10), isTrue);
    expect(isPassing(9.99), isFalse);
    expect(isPassing(roundGrade(9.995)), isTrue);
  });

  test('mentionFor: Tunisian mentions and their boundaries', () {
    expect(mentionFor(20), Mention.tresBien);
    expect(mentionFor(16), Mention.tresBien);
    expect(mentionFor(15.99), Mention.bien);
    expect(mentionFor(14), Mention.bien);
    expect(mentionFor(13.99), Mention.assezBien);
    expect(mentionFor(12), Mention.assezBien);
    expect(mentionFor(11.99), Mention.passable);
    expect(mentionFor(10), Mention.passable);
    expect(mentionFor(9.99), Mention.ajourne);
    expect(mentionFor(0), Mention.ajourne);

    expect(Mention.tresBien.label, 'Très Bien');
    expect(Mention.tresBien.standing, 'Excellent');
    expect(Mention.assezBien.label, 'Assez Bien');
    expect(Mention.ajourne.isPassing, isFalse);
    expect(Mention.passable.isPassing, isTrue);
  });

  test('letterGrade', () {
    expect(letterGrade(19), 'A+');
    expect(letterGrade(18), 'A+');
    expect(letterGrade(16.6), 'A');
    expect(letterGrade(16), 'A');
    expect(letterGrade(14.8), 'B+');
    expect(letterGrade(12.6), 'B');
    expect(letterGrade(10), 'C');
    expect(letterGrade(9.1), 'D');
    expect(letterGrade(7.99), 'F');
  });

  test('topPercent rounds up', () {
    expect(topPercent(7, 142), 5); // 4.93 %
    expect(topPercent(11, 142), 8); // 7.75 %
    expect(topPercent(48, 140), 35); // 34.29 %
    expect(topPercent(1, 100), 1);
    expect(topPercent(100, 100), 100);
  });

  group('evaluateSemester', () {
    final s8 = _semester('s8', [
      _course('CS-401', coefficient: 3, credits: 10, continuous: 17.5, exam: 16),
      _course('DB-408', coefficient: 2.5, credits: 8, continuous: 18, exam: 15.5),
      _course('SEC-402', coefficient: 2, credits: 7, continuous: 14.5, exam: 15),
      _course('HUM-304', coefficient: 1.5, credits: 5, continuous: 19),
    ], number: 8);

    test('validated semester with every course passed', () {
      final r = evaluateSemester(s8);
      expect(r.courses.map((c) => c.average), [16.6, 16.5, 14.8, 19.0]);
      expect(r.courses.map((c) => c.letter), ['A', 'A', 'B+', 'A+']);
      expect(r.courses.every((c) => c.status == CourseStatus.validated), isTrue);
      expect(r.average, 16.57);
      expect(r.mention, Mention.tresBien);
      expect(r.scorePercent, 83); // 16.57 / 20 = 82.85 %
      expect(r.creditsEarned, 30);
      expect(r.creditsTotal, 30);
      expect(r.isComplete, isTrue);
      expect(r.isValidated, isTrue);
      expect(r.isHonorRoll, isTrue);
      expect(r.delta, isNull);
      expect(r.courses.first.progress, closeTo(0.83, 1e-9));
    });

    test('delta against the previous semester', () {
      final s7 = _semester('s7', [
        _course('A', coefficient: 3, continuous: 16, exam: 15.5), // 15.70
        _course('B', coefficient: 2.5, continuous: 17, exam: 16.5), // 16.70
        _course('C', coefficient: 2, continuous: 15.5, exam: 16), // 15.80
        _course('D', coefficient: 1.5, continuous: 17, exam: 17), // 17.00
      ]);
      // (47.1 + 41.75 + 31.6 + 25.5) / 9 = 145.95 / 9 = 16.2166… → 16.22
      final r = evaluateSemester(s8, previous: s7);
      expect(r.previousAverage, 16.22);
      expect(r.delta, 0.35);

      final back = evaluateSemester(s7, previous: s8);
      expect(back.delta, -0.35);
    });

    test('a course below 10 is compensated when the semester is validated', () {
      final s = _semester('s6', [
        _course('POO', coefficient: 3, credits: 10, continuous: 14, exam: 13), // 13.40
        _course('AN', coefficient: 2.5, credits: 8, continuous: 10, exam: 8.5), // 9.10
        _course('SE', coefficient: 2, credits: 7, continuous: 13.5, exam: 12), // 12.60
        _course('FR', coefficient: 1.5, credits: 5, continuous: 15), // 15.00
      ]);
      // (40.2 + 22.75 + 25.2 + 22.5) / 9 = 110.65 / 9 = 12.2944… → 12.29
      final r = evaluateSemester(s);
      expect(r.average, 12.29);
      expect(r.mention, Mention.assezBien);
      expect(r.isValidated, isTrue);
      expect(r.courses[1].average, 9.1);
      expect(r.courses[1].status, CourseStatus.compensated);
      expect(r.courses[1].letter, 'D');
      expect(r.courses[1].creditsEarned, 8);
      expect(r.creditsEarned, 30);
      expect(r.isHonorRoll, isFalse); // < 14 and a compensated course
    });

    test('a course below 10 is failed when the semester is not validated', () {
      final s = _semester('x', [
        _course('A', coefficient: 2, credits: 6, continuous: 8, exam: 9), // 8.60
        _course('B', coefficient: 1, credits: 4, continuous: 12, exam: 11), // 11.40
      ]);
      // (17.2 + 11.4) / 3 = 9.5333… → 9.53
      final r = evaluateSemester(s);
      expect(r.average, 9.53);
      expect(r.mention, Mention.ajourne);
      expect(r.isValidated, isFalse);
      expect(r.courses[0].status, CourseStatus.failed);
      expect(r.courses[0].creditsEarned, 0);
      expect(r.courses[1].status, CourseStatus.validated);
      expect(r.creditsEarned, 4);
      expect(r.creditsTotal, 10);
    });

    test('an average of exactly 10 validates the semester', () {
      final r = evaluateSemester(_semester('x', [
        _course('A', coefficient: 1, continuous: 10, exam: 10),
        _course('B', coefficient: 1, continuous: 8, exam: 12), // 3.2 + 7.2 = 10.40
        _course('C', coefficient: 1, continuous: 9.6, exam: 9.6), // 9.60
      ]));
      // (10 + 10.4 + 9.6) / 3 = 10
      expect(r.average, 10.0);
      expect(r.mention, Mention.passable);
      expect(r.isValidated, isTrue);
      expect(r.courses[2].status, CourseStatus.compensated);
    });

    test('pending courses are left out of the average and earn no credits', () {
      final r = evaluateSemester(_semester('x', [
        _course('A', coefficient: 2, credits: 6, continuous: 12, exam: 12),
        _course('B', coefficient: 3, credits: 9),
      ]));
      expect(r.average, 12.0);
      expect(r.courses[1].status, CourseStatus.pending);
      expect(r.courses[1].letter, isNull);
      expect(r.isComplete, isFalse);
      expect(r.isValidated, isFalse);
      expect(r.creditsEarned, 6);
      expect(r.creditsTotal, 15);
      expect(r.isHonorRoll, isFalse);
    });

    test('nothing graded yet', () {
      final r = evaluateSemester(_semester('x', [_course('A')]));
      expect(r.average, isNull);
      expect(r.mention, isNull);
      expect(r.scorePercent, isNull);
      expect(r.creditsEarned, 0);
    });

    test('topCohortPercent only when the rank is valid', () {
      SemesterRecord ranked(int? rank, int? size) => SemesterRecord(
            id: 'r',
            academicYear: '2024–2025',
            number: 8,
            courses: const [],
            updatedAt: DateTime(2025),
            rank: rank,
            cohortSize: size,
          );
      expect(evaluateSemester(ranked(7, 142)).topCohortPercent, 5);
      expect(evaluateSemester(ranked(null, 142)).topCohortPercent, isNull);
      expect(evaluateSemester(ranked(150, 142)).topCohortPercent, isNull);
    });
  });

  group('semesterResultFor', () {
    final newest = _semester('new', [_course('A', continuous: 15, exam: 15)]);
    final older = _semester('old', [_course('A', continuous: 12, exam: 12)]);
    final transcript = AcademicTranscript(studentId: 'id', semesters: [newest, older]);

    test('defaults to the most recent semester, compared with the one before', () {
      final r = semesterResultFor(transcript, null)!;
      expect(r.semester.id, 'new');
      expect(r.delta, 3.0);
    });

    test('selects by id; the oldest has no trend', () {
      final r = semesterResultFor(transcript, 'old')!;
      expect(r.semester.id, 'old');
      expect(r.delta, isNull);
    });

    test('falls back to the most recent for an unknown id', () {
      expect(semesterResultFor(transcript, 'nope')!.semester.id, 'new');
    });

    test('null when nothing is published', () {
      expect(
        semesterResultFor(const AcademicTranscript(studentId: 'id', semesters: []), null),
        isNull,
      );
    });
  });
}
