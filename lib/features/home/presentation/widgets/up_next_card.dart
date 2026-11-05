import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../timetable/domain/entities/class_session.dart';

/// Purple hero card: the class happening now, otherwise the next one today.
class UpNextCard extends StatelessWidget {
  const UpNextCard({super.key, required this.sessions, required this.now, this.onTap});

  /// Today's sessions, sorted by start time.
  final List<ClassSession> sessions;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final statuses = sessionStatuses(sessions, now);
    final i = statuses.indexWhere(
      (s) => s == SessionStatus.ongoing || s == SessionStatus.next,
    );
    return _HeroSurface(
      onTap: onTap,
      child: i < 0
          ? _NoMoreClasses(hadClasses: sessions.isNotEmpty)
          : _SessionHero(
              session: sessions[i],
              ongoing: statuses[i] == SessionStatus.ongoing,
              now: now,
            ),
    );
  }
}

class _SessionHero extends StatelessWidget {
  const _SessionHero({required this.session, required this.ongoing, required this.now});

  final ClassSession session;
  final bool ongoing;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = session;
    final countdown = ongoing
        ? 'ends in ${formatShortDuration(s.end.difference(now))}'
        : 'in ${formatShortDuration(s.start.difference(now))}';
    final progress = s.courseProgress;
    final onHeroSmall = theme.textTheme.labelSmall?.copyWith(color: AppColors.onHero);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _HeroChip(label: ongoing ? 'NOW' : 'UP NEXT'),
            const SizedBox(width: AppSpacing.sm),
            _HeroChip(label: countdown, icon: Icons.timer_outlined, accent: true),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                formatTimeRange(s.start, s.end),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: onHeroSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          s.course,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontSize: 24,
            height: 32 / 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.36,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            const Icon(Icons.meeting_room_outlined, size: 18, color: AppColors.onHero),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${s.room} · ${s.teacher}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.onHero),
              ),
            ),
          ],
        ),
        if (progress != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text('Lecture ${s.lectureNumber} of ${s.lectureCount}', style: onHeroSmall),
              ),
              Text(
                '${(progress * 100).round()}% of the course',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.heroAccent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: AppColors.secondary,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
            ),
          ),
        ],
      ],
    );
  }
}

class _NoMoreClasses extends StatelessWidget {
  const _NoMoreClasses({required this.hadClasses});

  /// False on days without any class (weekends, holidays).
  final bool hadClasses;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _HeroChip(label: 'TODAY'),
        const SizedBox(height: AppSpacing.lg),
        Text(
          hadClasses ? 'No more classes today 🎉' : 'No classes today',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          hadClasses
              ? 'Time to rest, or find a ride home in the forum.'
              : 'Enjoy your free day!',
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.onHero),
        ),
      ],
    );
  }
}

/// Purple rounded surface with a coral glow and a dot pattern.
class _HeroSurface extends StatelessWidget {
  const _HeroSurface({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: AppRadius.lgAll,
      clipBehavior: Clip.antiAlias,
      elevation: 6,
      shadowColor: AppColors.primary.withValues(alpha: 0.5),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.secondary.withValues(alpha: 0.35),
                      AppColors.secondary.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned(
              right: 16,
              bottom: 8,
              child: CustomPaint(size: Size(100, 100), painter: _DotGridPainter()),
            ),
            Padding(padding: const EdgeInsets.all(AppSpacing.page), child: child),
          ],
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label, this.icon, this.accent = false});

  final String label;
  final IconData? icon;

  /// Solid coral instead of translucent white.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accent ? AppColors.secondary : Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
          ),
        ],
      ),
    );
  }
}

/// 5x5 grid of faint white dots (decoration from the design).
class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.1);
    final step = size.width / 5;
    for (var row = 0; row < 5; row++) {
      for (var col = 0; col < 5; col++) {
        canvas.drawCircle(Offset(step * (col + 0.5), step * (row + 0.5)), 3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
