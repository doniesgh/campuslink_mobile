import 'package:campuspulse/features/grades/presentation/grade_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatMark: 1 decimal, "--" when missing', () {
    expect(formatMark(17.5), '17.5');
    expect(formatMark(16), '16.0');
    expect(formatMark(null), '--');
  });

  test('formatAverage: 2 decimals, "--" when missing', () {
    expect(formatAverage(16.6), '16.60');
    expect(formatAverage(19), '19.00');
    expect(formatAverage(16.57), '16.57');
    expect(formatAverage(null), '--');
  });

  test('formatCoefficientLine', () {
    expect(formatCoefficientLine(3, 'CS-401'), 'Coeff 3.0 · CS-401');
    expect(formatCoefficientLine(2.5, 'DB-408'), 'Coeff 2.5 · DB-408');
  });

  test('formatDelta', () {
    expect(formatDelta(0.35), '+0.35 pts');
    expect(formatDelta(-0.2), '-0.20 pts');
    expect(formatDelta(0), '0.00 pts');
  });

  test('formatCredits / formatCourseCount / formatDocumentSize', () {
    expect(formatCredits(30, 30), '30 / 30 ECTS');
    expect(formatCourseCount(1), '1 Course');
    expect(formatCourseCount(4), '4 Courses');
    expect(formatDocumentSize(1.4), '1.4 MB · PDF');
  });
}
