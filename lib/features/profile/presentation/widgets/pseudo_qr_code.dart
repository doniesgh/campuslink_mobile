import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../utils/pseudo_qr.dart';

/// Gate-pass QR drawn with a [CustomPainter].
///
/// VISUAL PLACEHOLDER: the pattern is derived from [data] but is not a real,
/// scannable QR code. TODO: render the signed QR payload from the backend.
class PseudoQrCode extends StatelessWidget {
  const PseudoQrCode({super.key, required this.data, this.size = 56});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Student gate-pass code',
      child: CustomPaint(
        size: Size.square(size),
        painter: _PseudoQrPainter(data: data, matrix: pseudoQrMatrix(data)),
      ),
    );
  }
}

class _PseudoQrPainter extends CustomPainter {
  _PseudoQrPainter({required this.data, required this.matrix});

  final String data;
  final List<List<bool>> matrix;

  @override
  void paint(Canvas canvas, Size size) {
    // Always dark modules on white (scanners need the contrast, in both themes).
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final n = matrix.length;
    final cell = size.shortestSide / n;
    // One path so adjacent modules do not show anti-aliasing seams.
    final path = Path();
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        if (matrix[y][x]) path.addRect(Rect.fromLTWH(x * cell, y * cell, cell, cell));
      }
    }
    canvas.drawPath(path, Paint()..color = AppColors.neutral);
  }

  @override
  bool shouldRepaint(_PseudoQrPainter oldDelegate) => oldDelegate.data != data;
}
