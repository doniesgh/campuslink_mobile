import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/grading.dart';
import '../grade_format.dart';

/// Purple "Academic Standing" hero: standing, mention, average out of 20,
/// score gauge, ECTS credits and trend since the previous semester.
class StandingHeroCard extends StatelessWidget {
  const StandingHeroCard({super.key, required this.result, required this.now});

  final SemesterResult result;
  final DateTime now;

  /// Light mint used for the "excellence" star (tertiary-fixed in the design).
  static final Color _mint = Color.lerp(AppColors.success, Colors.white, 0.45)!;

  (IconData, String, Color) get _badge {
    if (!result.isComplete) return (Icons.hourglass_top, 'In Progress', AppColors.heroAccent);
    if (result.mention == Mention.tresBien) return (Icons.stars, 'Academic Excellence', _mint);
    if (result.isValidated) return (Icons.verified, 'Semester Validated', _mint);
    return (Icons.error_outline, 'Not Validated', AppColors.heroAccent);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mention = result.mention;
    final (badgeIcon, badgeLabel, badgeColor) = _badge;
    final onHeroSmall = theme.textTheme.labelSmall?.copyWith(color: AppColors.onHero);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.xlAll,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wraps instead of overflowing with large text.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                _HeroBadge(icon: badgeIcon, iconColor: badgeColor, label: badgeLabel),
                Text(
                  'Updated ${formatTimeAgo(result.semester.updatedAt, now: now)}',
                  style: onHeroSmall?.copyWith(
                    color: AppColors.onHero.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg + AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SEMESTER ${result.semester.number} STANDING',
                        style: onHeroSmall?.copyWith(letterSpacing: 0.4),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        mention?.standing ?? 'In Progress',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontSize: 20,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        switch (mention) {
                          null => '« Résultats en attente »',
                          Mention(isPassing: true, :final label) => '« Mention $label »',
                          Mention(:final label) => '« $label »',
                        },
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.onHero,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.end,
                        spacing: 6,
                        children: [
                          Text(
                            formatAverage(result.average),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: AppColors.secondary,
                              fontSize: 30,
                              height: 1,
                              letterSpacing: -0.6,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              '/ 20',
                              style: theme.textTheme.labelMedium
                                  ?.copyWith(color: AppColors.onHero),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                _ScoreGauge(percent: result.scorePercent),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.only(top: AppSpacing.md + 2),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _CreditsSummary(result: result),
                  if (result.delta case final delta?) _DeltaPill(delta: delta),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.icon, required this.iconColor, required this.label});

  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.onHero,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.55,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "✓ ECTS Credits Validated · 30 / 30 ECTS"
class _CreditsSummary extends StatelessWidget {
  const _CreditsSummary({required this.result});

  final SemesterResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = result.isValidated
        ? (Icons.check_circle, AppColors.success)
        : result.isComplete
            ? (Icons.error_outline, AppColors.danger)
            : (Icons.hourglass_top, AppColors.warning);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ECTS Credits Validated',
                style: theme.textTheme.labelSmall?.copyWith(color: AppColors.onHero),
              ),
              Text(
                formatCredits(result.creditsEarned, result.creditsTotal),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "↗ +0.35 pts" since the previous semester.
class _DeltaPill extends StatelessWidget {
  const _DeltaPill({required this.delta});

  final double delta;

  @override
  Widget build(BuildContext context) {
    final icon = delta > 0
        ? Icons.trending_up
        : delta < 0
            ? Icons.trending_down
            : Icons.trending_flat;
    return Tooltip(
      message: 'Since the previous semester',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.secondary),
            const SizedBox(width: AppSpacing.xs),
            Text(
              formatDelta(delta),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 96 px coral ring with "83% SCORE" in the middle.
class _ScoreGauge extends StatelessWidget {
  const _ScoreGauge({required this.percent});

  /// 0–100, null when there is no average yet.
  final int? percent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: percent == null ? 'Score not available' : 'Score $percent percent',
      excludeSemantics: true,
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.2,
        child: SizedBox.square(
          dimension: 96,
          child: CustomPaint(
            painter: _RingPainter(
              progress: (percent ?? 0) / 100,
              track: Colors.white.withValues(alpha: 0.15),
              color: AppColors.secondary,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    percent == null ? '--' : '$percent%',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontSize: 17,
                      height: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'SCORE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.onHero,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.track, required this.color});

  final double progress;
  final Color track;
  final Color color;

  static const _stroke = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    // r = 38 in a 96 px box, as in the design.
    final radius = size.shortestSide * 38 / 96;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke;
    canvas.drawCircle(center, radius, base..color = track);
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    if (sweep <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      base
        ..color = color
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.track != track || old.color != color;
}
