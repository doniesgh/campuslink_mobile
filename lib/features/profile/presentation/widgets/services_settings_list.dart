import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';

/// "Campus Services & Settings": grouped rows, the theme selector and sign out.
class ServicesSettingsList extends StatelessWidget {
  const ServicesSettingsList({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.onCurriculum,
    required this.onCarpool,
    required this.onNotifications,
    required this.onPrivacy,
    required this.onSignOut,
    this.semesterLabel,
    this.unreadNotifications = 0,
    this.hasCarpoolActivity = false,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final VoidCallback onCurriculum;
  final VoidCallback onCarpool;
  final VoidCallback onNotifications;
  final VoidCallback onPrivacy;
  final VoidCallback onSignOut;

  /// "S8" badge on the curriculum row (null while the profile loads).
  final String? semesterLabel;
  final int unreadNotifications;
  final bool hasCarpoolActivity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final semesterLabel = this.semesterLabel;
    final chevron = Icon(Icons.chevron_right, size: 18, color: scheme.outline);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text(
            'Campus Services & Settings',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
            border: dark
                ? Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4))
                : null,
            boxShadow: dark
                ? null
                : [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            children: [
              _ServiceRow(
                icon: Icons.auto_stories_outlined,
                tone: BadgeTone.primary,
                title: 'My Academic Curriculum',
                subtitle: 'Syllabus, modules & exam schedule',
                onTap: onCurriculum,
                trailing: _Trailing(
                  extra: semesterLabel == null ? null : AppBadge(semesterLabel),
                  chevron: chevron,
                ),
              ),
              _ServiceRow(
                icon: Icons.directions_car_outlined,
                tone: BadgeTone.accent,
                title: 'Covoiturage & Co-riders',
                subtitle: 'ESPRIT carpool pass & rides',
                onTap: onCarpool,
                trailing: _Trailing(
                  extra: hasCarpoolActivity
                      ? Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: scheme.secondary,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                  chevron: chevron,
                ),
              ),
              _ServiceRow(
                icon: Icons.notifications_active_outlined,
                tone: BadgeTone.primary,
                title: 'Notifications & Alerts',
                subtitle: 'Absences, room changes, grades',
                onTap: onNotifications,
                trailing: _Trailing(
                  extra: unreadNotifications > 0
                      ? AppBadge('$unreadNotifications new', tone: BadgeTone.accent, solid: true)
                      : null,
                  chevron: chevron,
                ),
              ),
              _ServiceRow(
                icon: Icons.palette_outlined,
                tone: BadgeTone.neutral,
                title: 'Appearance',
                subtitle: 'Theme preferences',
                trailing: ThemeModeSelector(mode: themeMode, onChanged: onThemeModeChanged),
              ),
              _ServiceRow(
                icon: Icons.lock_outline,
                tone: BadgeTone.success,
                title: 'Campus SSO & Privacy',
                subtitle: 'Manage Office365 & credentials',
                onTap: onPrivacy,
                trailing: chevron,
              ),
              _ServiceRow(
                icon: Icons.logout,
                iconColors: (
                  scheme.errorContainer.withValues(alpha: dark ? 0.4 : 1),
                  dark ? scheme.onErrorContainer : scheme.error,
                ),
                title: 'Sign Out',
                titleColor: scheme.error,
                subtitle: 'Disconnect this device',
                onTap: onSignOut,
                trailing: Icon(Icons.arrow_forward, size: 18, color: scheme.error),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.tone = BadgeTone.primary,
    this.iconColors,
    this.titleColor,
    this.onTap,
  });

  final IconData icon;
  final BadgeTone tone;

  /// Overrides the [tone] colors: (background, foreground).
  final (Color, Color)? iconColors;
  final String title;
  final Color? titleColor;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (iconBg, iconFg) = iconColors ?? toneColors(scheme, tone);
    final radius = BorderRadius.circular(16);
    final row = Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: iconFg),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(color: titleColor),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          trailing,
        ],
      ),
    );
    return Material(
      type: MaterialType.transparency,
      child: onTap == null
          ? row
          : InkWell(borderRadius: radius, onTap: onTap, child: row),
    );
  }
}

/// Optional badge/dot followed by the chevron.
class _Trailing extends StatelessWidget {
  const _Trailing({required this.chevron, this.extra});

  final Widget? extra;
  final Widget chevron;

  @override
  Widget build(BuildContext context) {
    final extra = this.extra;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (extra != null) ...[extra, const SizedBox(width: AppSpacing.sm)],
        chevron,
      ],
    );
  }
}

/// Compact Light / System / Dark segmented pill (replaces the design's single
/// "Toggle" button so the "System" mode stays reachable).
class ThemeModeSelector extends StatelessWidget {
  const ThemeModeSelector({super.key, required this.mode, required this.onChanged});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  static const _options = [
    (ThemeMode.light, 'Light', Icons.light_mode_outlined),
    (ThemeMode.system, 'System', Icons.brightness_auto_outlined),
    (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (value, label, icon) in _options)
            _ModeButton(
              label: label,
              icon: icon,
              selected: value == mode,
              onTap: () => onChanged(value),
            ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: Material(
          color: selected ? scheme.primary : Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox.square(
              dimension: 34,
              child: Icon(
                icon,
                size: 18,
                color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
