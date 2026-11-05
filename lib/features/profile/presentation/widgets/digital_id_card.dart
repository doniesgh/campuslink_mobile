import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/student_profile.dart';
import '../utils/initials.dart';
import 'pseudo_qr_code.dart';

/// "Digital Student ID" title row + the dark "obsidian" student card.
class DigitalIdSection extends StatelessWidget {
  const DigitalIdSection({
    super.key,
    required this.profile,
    required this.name,
    required this.now,
  });

  final StudentProfile profile;
  final String name;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Digital Student ID',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (profile.isVerified) ...[
                Icon(Icons.verified_outlined, size: 15, color: scheme.primary),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Verified ESPRIT',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        DigitalIdCard(profile: profile, name: name, now: now),
      ],
    );
  }
}

/// Card colors: dark in both themes (inverse surface in light mode, a raised
/// dark surface with a border in dark mode), as in the two Stitch designs.
class _IdPalette {
  factory _IdPalette.of(ColorScheme s) {
    final dark = s.brightness == Brightness.dark;
    return dark
        ? _IdPalette._(
            background: s.surfaceContainerLow,
            border: s.outlineVariant.withValues(alpha: 0.6),
            strong: s.onSurface,
            muted: s.onSurfaceVariant,
            strip: s.surface,
            stripBorder: s.outlineVariant.withValues(alpha: 0.4),
            chip: s.surfaceContainerHigh,
            keyChip: AppColors.primary,
            keyChipText: Colors.white,
          )
        : _IdPalette._(
            background: s.inverseSurface,
            border: null,
            strong: s.onInverseSurface,
            muted: s.onInverseSurface.withValues(alpha: 0.72),
            strip: s.onInverseSurface.withValues(alpha: 0.08),
            stripBorder: null,
            chip: s.onInverseSurface.withValues(alpha: 0.14),
            keyChip: AppColors.primary.withValues(alpha: 0.6),
            keyChipText: AppColors.onHero,
          );
  }

  const _IdPalette._({
    required this.background,
    required this.border,
    required this.strong,
    required this.muted,
    required this.strip,
    required this.stripBorder,
    required this.chip,
    required this.keyChip,
    required this.keyChipText,
  });

  final Color background;
  final Color? border;
  final Color strong;
  final Color muted;
  final Color strip;
  final Color? stripBorder;
  final Color chip;
  final Color keyChip;
  final Color keyChipText;
}

class DigitalIdCard extends StatelessWidget {
  const DigitalIdCard({
    super.key,
    required this.profile,
    required this.name,
    required this.now,
  });

  final StudentProfile profile;
  final String name;

  /// Used to show "Active Student" or "Card expired".
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = _IdPalette.of(scheme);
    final valid = profile.isValidOn(now);
    final border = p.border;
    final stripBorder = p.stripBorder;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.page),
      decoration: BoxDecoration(
        color: p.background,
        borderRadius: AppRadius.xlAll,
        border: border == null ? null : Border.all(color: border),
        boxShadow: AppShadows.elevated(scheme),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Institutional header
          Row(
            children: [
              Expanded(
                child: Text(
                  'RÉPUBLIQUE TUNISIENNE · ESPRIT INGÉNIERIE',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: p.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _Chip(
                label: profile.academicYearLabel,
                background: AppColors.secondary.withValues(alpha: 0.3),
                foreground: AppColors.heroAccent,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Divider(height: 1, thickness: 1, color: p.strong.withValues(alpha: 0.12)),
          ),
          // Photo + identity
          Row(
            children: [
              _IdPhoto(name: name),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STUDENT ID',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: p.muted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      profile.studentId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: p.strong,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: p.strong,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile.cardProgramLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.page),
          // Gate-pass QR + status chips
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: p.strip,
              borderRadius: AppRadius.lgAll,
              border: stripBorder == null ? null : Border.all(color: stripBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: PseudoQrCode(data: profile.studentId),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: valid ? AppColors.success : scheme.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              valid ? 'Active Student' : 'Card expired',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: p.strong,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          if (profile.nfcReady)
                            _Chip(label: 'NFC Ready 📡', background: p.chip, foreground: p.muted),
                          if (profile.hasEspritKey)
                            _Chip(
                              label: 'ESPRIT-KEY',
                              background: p.keyChip,
                              foreground: p.keyChipText,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Initials in place of the passport photo.
class _IdPhoto extends StatelessWidget {
  const _IdPhoto({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: AppColors.hero,
        borderRadius: AppRadius.mdAll,
      ),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: Text(
          initialsOf(name),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.onHero,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.background, required this.foreground});

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
