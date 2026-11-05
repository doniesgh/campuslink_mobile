import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../domain/entities/ride.dart';

/// Stylised route preview (no map SDK / API key needed yet).
/// Replace the painter with flutter_map or Google Maps when real coordinates exist.
class RouteMapPreview extends StatelessWidget {
  const RouteMapPreview({super.key, required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: AppRadius.lgAll,
      child: SizedBox(
        height: 170,
        width: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: scheme.surfaceContainerHigh),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _RouteMapPainter(
                  water: dark ? AppColors.mapWaterDark : AppColors.mapWater,
                  road: scheme.surfaceContainerLowest,
                  route: scheme.secondary,
                  start: scheme.primary,
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  AppBadge(ride.pickupTag, tone: BadgeTone.neutral, icon: Icons.trip_origin),
                  AppBadge('~${ride.duration.inMinutes} min', tone: BadgeTone.primary, icon: Icons.schedule),
                  AppBadge(ride.dropoffTag, tone: BadgeTone.success, icon: Icons.school_outlined),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteMapPainter extends CustomPainter {
  _RouteMapPainter({
    required this.water,
    required this.road,
    required this.route,
    required this.start,
  });

  final Color water;
  final Color road;
  final Color route;
  final Color start;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Lake / sea
    final waterPath = Path()
      ..moveTo(w * 0.55, 0)
      ..quadraticBezierTo(w * 0.45, h * 0.35, w * 0.7, h * 0.55)
      ..quadraticBezierTo(w * 0.9, h * 0.7, w, h * 0.6)
      ..lineTo(w, 0)
      ..close();
    canvas.drawPath(waterPath, Paint()..color = water);

    // Streets
    final roads = Paint()
      ..color = road
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, h * 0.30), Offset(w, h * 0.46), roads);
    canvas.drawLine(Offset(w * 0.20, 0), Offset(w * 0.34, h), roads);
    canvas.drawLine(Offset(0, h * 0.82), Offset(w * 0.8, h * 0.68), roads);

    // Route
    final from = Offset(w * 0.12, h * 0.70);
    final to = Offset(w * 0.88, h * 0.22);
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..cubicTo(w * 0.35, h * 0.15, w * 0.6, h * 0.85, to.dx, to.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = route
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Start / end markers
    final white = Paint()..color = Colors.white;
    canvas.drawCircle(from, 8, white);
    canvas.drawCircle(from, 5, Paint()..color = start);
    canvas.drawCircle(to, 9, white);
    canvas.drawCircle(to, 6, Paint()..color = route);
  }

  @override
  bool shouldRepaint(covariant _RouteMapPainter old) =>
      old.water != water || old.road != road || old.route != route || old.start != start;
}
