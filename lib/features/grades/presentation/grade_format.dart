// Text formatting of marks and credits for the grades screen (pure Dart).

/// Raw mark with 1 decimal ("17.5"), or "--" when missing.
String formatMark(double? mark) => mark == null ? '--' : mark.toStringAsFixed(1);

/// Average with 2 decimals ("16.60"), or "--" when missing.
String formatAverage(double? average) =>
    average == null ? '--' : average.toStringAsFixed(2);

/// "Coeff 3.0 · CS-401"
String formatCoefficientLine(double coefficient, String code) =>
    'Coeff ${coefficient.toStringAsFixed(1)} · $code';

/// "+0.35 pts" / "-0.20 pts" / "0.00 pts"
String formatDelta(double delta) {
  final sign = delta > 0
      ? '+'
      : delta < 0
          ? '-'
          : '';
  return '$sign${delta.abs().toStringAsFixed(2)} pts';
}

/// "30 / 30 ECTS"
String formatCredits(int earned, int total) => '$earned / $total ECTS';

/// "1 Course" / "4 Courses"
String formatCourseCount(int count) => '$count Course${count == 1 ? '' : 's'}';

/// "1.4 MB · PDF"
String formatDocumentSize(double megabytes) => '${megabytes.toStringAsFixed(1)} MB · PDF';
