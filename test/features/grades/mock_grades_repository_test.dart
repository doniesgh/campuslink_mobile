import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/features/grades/data/repositories/mock_grades_repository.dart';
import 'package:campuspulse/features/grades/domain/entities/academic_transcript.dart';
import 'package:campuspulse/features/grades/domain/grading.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AcademicTranscript> _transcriptAt(DateTime now) async {
  final repo = MockGradesRepository(latency: Duration.zero, clock: () => now);
  return ((await repo.getTranscript()) as Success<AcademicTranscript>).value;
}

void main() {
  group('November 2026 (4th year, current S7)', () {
    final now = DateTime(2026, 11, 5, 10);
    late AcademicTranscript transcript;

    setUpAll(() async => transcript = await _transcriptAt(now));

    test('publishes the three previous semesters, most recent first', () {
      expect(transcript.studentId, 'CP-2024-8891');
      expect(transcript.semesters.map((s) => s.label), [
        '2025–2026 · Sem 6',
        '2025–2026 · Sem 5',
        '2024–2025 · Sem 4',
      ]);
      expect(
        transcript.semesters.map((s) => s.id),
        ['2025-2026-s6', '2025-2026-s5', '2024-2025-s4'],
      );
    });

    test('latest updated 2 h ago, older ones on their publication dates', () {
      expect(
        transcript.semesters.map((s) => s.updatedAt),
        [
          DateTime(2026, 11, 5, 8),
          DateTime(2026, 2, 7, 14, 30), // fall S5, published in February
          DateTime(2025, 7, 3, 10), // spring S4, published in July
        ],
      );
    });

    test('latest: the design cards, average computed from the marks', () {
      final r = semesterResultFor(transcript, null)!;
      expect(r.semester.number, 6);
      expect(r.courses.map((c) => c.average), [16.6, 16.5, 14.8, 19.0]);
      expect(r.average, 16.57);
      expect(r.mention, Mention.tresBien);
      expect(r.scorePercent, 83);
      expect(r.creditsEarned, 30);
      expect(r.creditsTotal, 30);
      expect(r.previousAverage, 16.22);
      expect(r.delta, 0.35);
      expect(r.topCohortPercent, 5);
      expect(r.isHonorRoll, isTrue);
    });

    test('oldest: one compensated course, still 30 ECTS', () {
      final r = semesterResultFor(transcript, '2024-2025-s4')!;
      expect(r.semester.number, 4);
      expect(r.average, 12.29);
      expect(r.mention, Mention.assezBien);
      expect(
        r.courses.map((c) => c.status),
        [
          CourseStatus.validated,
          CourseStatus.compensated,
          CourseStatus.validated,
          CourseStatus.validated,
        ],
      );
      expect(r.creditsEarned, 30);
      expect(r.delta, isNull);
      expect(r.topCohortPercent, 35);
      expect(r.isHonorRoll, isFalse);
    });
  });

  test('March 2027 (spring, current S8): Sem 7, 6, 5', () async {
    final now = DateTime(2027, 3, 10, 9);
    final t = await _transcriptAt(now);
    expect(t.semesters.map((s) => s.label), [
      '2026–2027 · Sem 7',
      '2025–2026 · Sem 6',
      '2025–2026 · Sem 5',
    ]);
    expect(
      t.semesters.map((s) => s.id),
      ['2026-2027-s7', '2025-2026-s6', '2025-2026-s5'],
    );
    expect(
      t.semesters.map((s) => s.updatedAt),
      [now.subtract(const Duration(hours: 2)), DateTime(2026, 7, 3, 10), DateTime(2026, 2, 7, 14, 30)],
    );
    // Same marks whatever the numbers.
    expect(semesterResultFor(t, null)!.average, 16.57);
    expect(semesterResultFor(t, '2025-2026-s5')!.average, 12.29);
  });

  test('January 2027 is still the fall (current S7): Sem 6, 5, 4', () async {
    final t = await _transcriptAt(DateTime(2027, 1, 15, 9));
    expect(t.semesters.map((s) => s.label), [
      '2025–2026 · Sem 6',
      '2025–2026 · Sem 5',
      '2024–2025 · Sem 4',
    ]);
  });

  test('September 2027 starts a new academic year (current S7 again)', () async {
    final t = await _transcriptAt(DateTime(2027, 9, 20));
    expect(t.semesters.first.label, '2026–2027 · Sem 6');
    expect(t.semesters.last.label, '2025–2026 · Sem 4');
  });
}
