import 'package:campuspulse/features/profile/presentation/utils/pseudo_qr.dart';
import 'package:flutter_test/flutter_test.dart';

/// True when the 7x7 square at (top, left) is a finder pattern
/// (dark ring, white ring, dark 3x3 core).
bool _isFinder(List<List<bool>> m, int top, int left) {
  for (var r = 0; r < 7; r++) {
    for (var c = 0; c < 7; c++) {
      final ring = r == 0 || r == 6 || c == 0 || c == 6;
      final core = r >= 2 && r <= 4 && c >= 2 && c <= 4;
      if (m[top + r][left + c] != (ring || core)) return false;
    }
  }
  return true;
}

void main() {
  const id = '211JMT0428';

  group('pseudoQrMatrix', () {
    test('is a square matrix of the requested size', () {
      final m = pseudoQrMatrix(id);
      expect(m.length, 21);
      expect(m.every((row) => row.length == 21), isTrue);
      expect(pseudoQrMatrix(id, size: 25).length, 25);
    });

    test('rejects sizes smaller than a version-1 QR code', () {
      expect(() => pseudoQrMatrix(id, size: 15), throwsArgumentError);
    });

    test('is deterministic for a given seed', () {
      expect(pseudoQrMatrix(id), pseudoQrMatrix(id));
    });

    test('differs between seeds', () {
      expect(pseudoQrMatrix(id), isNot(pseudoQrMatrix('211JMT0429')));
      expect(pseudoQrMatrix(id), isNot(pseudoQrMatrix('')));
    });

    test('has the three finder squares with white separators', () {
      for (final seed in [id, '', 'x', 'another-student-id']) {
        final m = pseudoQrMatrix(seed);
        expect(_isFinder(m, 0, 0), isTrue, reason: 'top-left, seed "$seed"');
        expect(_isFinder(m, 0, 14), isTrue, reason: 'top-right, seed "$seed"');
        expect(_isFinder(m, 14, 0), isTrue, reason: 'bottom-left, seed "$seed"');
        for (var i = 0; i < 8; i++) {
          expect(m[7][i], isFalse); // under top-left
          expect(m[i][7], isFalse); // right of top-left
          expect(m[7][20 - i], isFalse); // under top-right
          expect(m[i][13], isFalse); // left of top-right
          expect(m[13][i], isFalse); // above bottom-left
          expect(m[20 - i][7], isFalse); // right of bottom-left
        }
      }
    });

    test('has alternating timing lines', () {
      final m = pseudoQrMatrix(id);
      for (var i = 8; i < 13; i++) {
        expect(m[6][i], i.isEven);
        expect(m[i][6], i.isEven);
      }
    });

    test('fills the data area with a balanced mix of modules', () {
      final m = pseudoQrMatrix(id);
      // Bottom-right block: no finder, no timing line.
      var dark = 0;
      for (var y = 9; y < 21; y++) {
        for (var x = 9; x < 21; x++) {
          if (m[y][x]) dark++;
        }
      }
      final ratio = dark / (12 * 12);
      expect(ratio, inInclusiveRange(0.3, 0.7));
    });
  });
}
