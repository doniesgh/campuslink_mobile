import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/course.dart';
import '../utils/course_formatters.dart';

/// Purple hero card: modules completed, pace, mastery ring and next quiz.
/// Tapping it opens the module list.
class MasteryCard extends StatelessWidget {
  const MasteryCard({super.key, required this.course, required this.now, this.onTap});

  final Course course;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quiz = course.nextQuiz;
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      clipBehavior: Clip.antiAlias,
      elevation: 6,
      shadowColor: AppColors.primary.withValues(alpha: 0.5),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _HeroPill(icon: Icons.insights, label: 'Course Mastery'),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '${course.completedModules} / ${course.modules.length} Modules',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontSize: 20,
                                  height: 28 / 20,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            if (onTap != null)
                              Icon(
                                Icons.chevron_right,
                                size: 22,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          paceLabel(course.pace),
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.onHero),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  MasteryRing(value: course.mastery, percent: course.masteryPercent),
                ],
              ),
              if (quiz != null) ...[
                const SizedBox(height: AppSpacing.lg),
                _QuizPill(quiz: quiz, now: now),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 96 dp coral ring on a translucent track, with "72% Passed" inside.
class MasteryRing extends StatelessWidget {
  const MasteryRing({super.key, required this.value, required this.percent});

  /// 0..1
  final double value;
  final int percent;

  static const _size = 96.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Course mastery $percent percent passed',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: _size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (_, v, child) => CustomPaint(
            painter: _RingPainter(
              value: v,
              color: AppColors.secondary,
              trackColor: Colors.white.withValues(alpha: 0.2),
            ),
            child: child,
          ),
          // Fixed-size ring: cap text scaling so the label stays inside.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.2,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$percent%',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontSize: 17,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Passed',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.heroAccent,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
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
  const _RingPainter({required this.value, required this.color, required this.trackColor});

  final double value;
  final Color color;
  final Color trackColor;

  static const _stroke = 7.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    // Same proportions as the design (r = 38 in a 96 box).
    final radius = size.shortestSide * 38 / 96;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..color = trackColor;
    canvas.drawCircle(center, radius, paint);
    if (value <= 0) return;
    paint
      ..color = color
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * value,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.trackColor != trackColor;
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.heroAccent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.heroAccent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Next quiz in **4 days** (Arch Microservices)"
class _QuizPill extends StatelessWidget {
  const _QuizPill({required this.quiz, required this.now});

  final CourseQuiz quiz;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final countdown = quizCountdown(quiz.date, now);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.15),
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          const Icon(Icons.quiz, size: 18, color: AppColors.secondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Next quiz ${countdown.lead}'),
                  TextSpan(
                    text: countdown.highlight,
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(text: ' (${quiz.topic})'),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
            ),
          ),
        ],
      ),
    );
  }
}
