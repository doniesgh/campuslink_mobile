import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../domain/entities/class_session.dart';
import '../../domain/schedule_logic.dart';
import '../timetable_format.dart';
import 'pulsing_dot.dart';

/// A session of the day timeline. Evaluations and the session in progress
/// are raised; past sessions are faded.
class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.session,
    required this.status,
    required this.now,
    this.onTap,
    this.onFindSeat,
  });

  final ClassSession session;
  final SessionStatus status;
  final DateTime now;
  final VoidCallback? onTap;

  /// "Find Seat" on upcoming evaluations.
  final VoidCallback? onFindSeat;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = status == SessionStatus.done;
    final exam = session.kind == SessionKind.exam;
    final raised = !done && (exam || status == SessionStatus.ongoing);

    final Widget content = switch (status) {
      _ when exam => _ExamContent(session: session, done: done, onFindSeat: onFindSeat),
      SessionStatus.ongoing => _OngoingContent(session: session, now: now),
      _ => _StandardContent(session: session, status: status, now: now),
    };

    final card = _CardShell(
      background: raised ? scheme.surfaceContainerHigh : scheme.surfaceContainerLowest,
      raised: raised,
      bar: session.kind == SessionKind.lecture ? scheme.primary : scheme.secondary,
      padding: EdgeInsets.all(raised ? AppSpacing.lg : 14),
      onTap: onTap,
      child: content,
    );
    return done ? Opacity(opacity: 0.85, child: card) : card;
  }
}

/// Free period between two sessions ("🍴 Free Period ✦ Déjeuner & Révision").
class BreakCard extends StatelessWidget {
  const BreakCard({super.key, required this.entry});

  final TimelineBreak entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lunch = entry.isLunch;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: AppRadius.mdAll),
            child: Icon(
              lunch ? Icons.restaurant : Icons.local_cafe_outlined,
              size: 20,
              color: _accentText(scheme),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lunch ? '🍴 Free Period ✦ Déjeuner & Révision' : '☕ Free Period ✦ Révision',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurface),
                ),
                Text(
                  lunch
                      ? 'Student Hub Cafeteria · Espaces Coworking'
                      : 'Bibliothèque · Espaces Coworking',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _Pill(
            label: formatCompactDuration(entry.length),
            background: scheme.surfaceContainer,
            foreground: scheme.outline,
            radius: AppRadius.sm,
          ),
        ],
      ),
    );
  }
}

/// Coral text/icons ("secondary" in the design): darker in light mode for contrast.
Color _accentText(ColorScheme scheme) => toneColors(scheme, BadgeTone.accent).$2;

Color _kindColor(ColorScheme scheme, SessionKind kind) =>
    kind == SessionKind.lecture ? scheme.primary : _accentText(scheme);

/// Past, next or later session.
class _StandardContent extends StatelessWidget {
  const _StandardContent({required this.session, required this.status, required this.now});

  final ClassSession session;
  final SessionStatus status;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = session;
    final (softBg, softFg) = toneColors(scheme, BadgeTone.accent);
    final (neutralBg, neutralFg) = toneColors(scheme, BadgeTone.neutral);

    final Widget chip = switch (status) {
      SessionStatus.done => _Pill(
          label: 'Passed',
          background: scheme.surfaceContainer,
          foreground: scheme.onSurfaceVariant,
          leading: const Icon(Icons.check, size: 14, color: AppColors.success),
        ),
      SessionStatus.next => _Pill(
          label: 'Starts in ${formatCompactDuration(s.start.difference(now))}',
          background: softBg,
          foreground: softFg,
        ),
      _ => _Pill(label: formatSessionLength(s.duration), background: neutralBg, foreground: neutralFg),
    };

    final (IconData roomIcon, Color roomColor) = status == SessionStatus.done
        ? (Icons.location_on_outlined, scheme.primary)
        : (Icons.domain, _accentText(scheme));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CardHeader(label: sessionKindLabel(s.kind), color: _kindColor(scheme, s.kind), trailing: chip),
        const SizedBox(height: 2),
        _Title(s.course),
        const SizedBox(height: 10),
        _MetaRow(
          first: _Meta(icon: roomIcon, iconColor: roomColor, text: s.room),
          second: _Meta(icon: Icons.person_outline, text: s.teacher),
        ),
      ],
    );
  }
}

/// The session happening now, with its progress.
class _OngoingContent extends StatelessWidget {
  const _OngoingContent({required this.session, required this.now});

  final ClassSession session;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = session;
    final (solidBg, solidFg) = toneColors(scheme, BadgeTone.accent, solid: true);
    final p = sessionProgress(s, now);
    final small = theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CardHeader(
          label: sessionKindLabel(s.kind),
          color: _kindColor(scheme, s.kind),
          trailing: _Pill(
            label: '${formatSessionLength(s.duration)} · In Progress',
            background: solidBg,
            foreground: solidFg,
            leading: PulsingDot(color: solidFg, size: 6),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _Title(s.course),
        const SizedBox(height: AppSpacing.md),
        _SpreadOrWrap(
          children: [
            Text('Time elapsed: ${formatCompactDuration(p.elapsed, roundUp: false)}', style: small),
            Text('${formatCompactDuration(p.remaining)} left', style: small),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: p.progress,
            minHeight: 6,
            color: scheme.primary,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _MetaRow(
          first: _Meta(
            icon: Icons.meeting_room_outlined,
            iconColor: _accentText(scheme),
            text: s.room,
            strong: true,
          ),
          second: _Meta(icon: Icons.school_outlined, text: s.teacher),
        ),
      ],
    );
  }
}

/// Exams and graded evaluations.
class _ExamContent extends StatelessWidget {
  const _ExamContent({required this.session, required this.done, this.onFindSeat});

  final ClassSession session;
  final bool done;
  final VoidCallback? onFindSeat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = session;
    final (solidBg, solidFg) = toneColors(scheme, BadgeTone.accent, solid: true);
    final notes = s.notes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CardHeader(
          label: sessionKindLabel(s.kind),
          color: _kindColor(scheme, s.kind),
          trailing: done
              ? _Pill(
                  label: 'Passed',
                  background: scheme.surfaceContainer,
                  foreground: scheme.onSurfaceVariant,
                  leading: const Icon(Icons.check, size: 14, color: AppColors.success),
                )
              : _Pill(
                  label: formatEvaluationLabel(s.coefficient),
                  background: solidBg,
                  foreground: solidFg,
                  bold: true,
                ),
        ),
        const SizedBox(height: 6),
        _Title(s.course),
        if (notes != null) ...[
          const SizedBox(height: 2),
          Text(
            notes,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        _SpreadOrWrap(
          children: [
            _Meta(
              icon: Icons.pin_drop_outlined,
              iconColor: _accentText(scheme),
              iconSize: 18,
              text: s.room,
              strong: true,
            ),
            if (!done && onFindSeat != null) _FindSeatButton(onTap: onFindSeat!),
          ],
        ),
      ],
    );
  }
}

/// Rounded card with a vertical accent bar on the left.
class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.background,
    required this.raised,
    required this.bar,
    required this.padding,
    required this.child,
    this.onTap,
  });

  final Color background;
  final bool raised;
  final Color bar;
  final EdgeInsets padding;
  final Widget child;
  final VoidCallback? onTap;

  static const _barWidth = 6.0;
  static const _barGap = AppSpacing.md;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: raised
            ? AppShadows.card(scheme)
            : [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: AppRadius.lgAll,
          onTap: onTap,
          child: Stack(
            children: [
              Padding(
                padding: padding.copyWith(left: padding.left + _barWidth + _barGap),
                child: child,
              ),
              Positioned(
                left: padding.left,
                top: padding.top,
                bottom: padding.bottom,
                width: _barWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: bar,
                    borderRadius: BorderRadius.circular(_barWidth / 2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Children at both ends of the line, or one under the other when they
/// don't fit (narrow screens, large fonts).
class _SpreadOrWrap extends StatelessWidget {
  const _SpreadOrWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: children,
    );
  }
}

/// "LAB / TP                 [2 hrs · In Progress]"
class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.label, required this.color, required this.trailing});

  final String label;
  final Color color;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return _SpreadOrWrap(
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
        ),
        trailing,
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
    this.leading,
    this.bold = false,
    this.radius = 20,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Widget? leading;
  final bool bold;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(radius)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 5)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: foreground,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Room and teacher, side by side.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(child: first),
        const SizedBox(width: AppSpacing.md),
        Flexible(child: second),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({
    required this.icon,
    required this.text,
    this.iconColor,
    this.iconSize = 16,
    this.strong = false,
  });

  final IconData icon;
  final String text;
  final Color? iconColor;
  final double iconSize;

  /// Bold, full-contrast text (the room of the current session or exam).
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: iconColor ?? scheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: strong ? scheme.onSurface : scheme.onSurfaceVariant,
              fontWeight: strong ? FontWeight.w600 : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _FindSeatButton extends StatelessWidget {
  const _FindSeatButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.primary,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        borderRadius: AppRadius.mdAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 14, color: scheme.onPrimary),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  'Find Seat',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
