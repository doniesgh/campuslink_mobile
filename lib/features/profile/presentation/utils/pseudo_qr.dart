/// VISUAL PLACEHOLDER ONLY: this builds a QR-*looking* module matrix, it does
/// NOT encode anything and cannot be scanned.
///
/// TODO: replace with a real, signed gate-pass QR payload from the backend
/// (rendered by a proper QR encoder) once the campus access API exists.
library;

/// Smallest supported size: a version-1 QR code is 21x21 modules.
const int pseudoQrMinSize = 21;

/// Deterministic pseudo-QR matrix derived from [seed] (the student ID).
///
/// `matrix[row][col]` is true for a dark module. It has the three finder
/// squares (top-left, top-right, bottom-left) with their white separators,
/// the two timing lines, and pseudo-random "data" modules elsewhere.
/// The same seed always gives the same matrix.
List<List<bool>> pseudoQrMatrix(String seed, {int size = pseudoQrMinSize}) {
  if (size < pseudoQrMinSize) {
    throw ArgumentError.value(size, 'size', 'must be at least $pseudoQrMinSize');
  }
  final dark = List.generate(size, (_) => List<bool>.filled(size, false));
  final reserved = List.generate(size, (_) => List<bool>.filled(size, false));

  // 7x7 finder square + its 1-module white separator.
  void finder(int top, int left) {
    for (var r = -1; r <= 7; r++) {
      for (var c = -1; c <= 7; c++) {
        final y = top + r;
        final x = left + c;
        if (y < 0 || y >= size || x < 0 || x >= size) continue;
        reserved[y][x] = true;
        final inSquare = r >= 0 && r <= 6 && c >= 0 && c <= 6;
        final ring = r == 0 || r == 6 || c == 0 || c == 6;
        final core = r >= 2 && r <= 4 && c >= 2 && c <= 4;
        dark[y][x] = inSquare && (ring || core);
      }
    }
  }

  finder(0, 0);
  finder(0, size - 7);
  finder(size - 7, 0);

  // Timing patterns between the finders.
  for (var i = 8; i < size - 8; i++) {
    dark[6][i] = i.isEven;
    dark[i][6] = i.isEven;
    reserved[6][i] = true;
    reserved[i][6] = true;
  }

  var state = _seedOf(seed);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      if (reserved[y][x]) continue;
      state = _xorshift32(state);
      dark[y][x] = (state >> 11) & 1 == 1;
    }
  }
  return dark;
}

/// Stable, non-zero 31-bit hash of [s] (kept small so it is exact on the web too).
int _seedOf(String s) {
  var h = 17;
  for (final unit in s.codeUnits) {
    h = (h * 31 + unit) & 0x7FFFFFFF;
  }
  // Warm up so short / similar seeds diverge quickly.
  h = _xorshift32(_xorshift32(h == 0 ? 0x5EED : h));
  return h == 0 ? 0x5EED : h;
}

int _xorshift32(int x) {
  x ^= (x << 13) & 0xFFFFFFFF;
  x ^= x >> 17;
  x ^= (x << 5) & 0xFFFFFFFF;
  return x & 0xFFFFFFFF;
}
