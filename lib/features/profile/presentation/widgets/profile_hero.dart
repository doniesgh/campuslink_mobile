import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/user_avatar.dart';

const double _bannerHeight = 144;
const double _avatarSize = 96;
const double _avatarOverlap = 56;

/// Purple curved banner with the overlapping avatar, name, program and the
/// coral "NFC Student Pass" button.
class ProfileHero extends StatelessWidget {
  const ProfileHero({
    super.key,
    required this.name,
    required this.onEdit,
    required this.onNfcPass,
    this.programLine,
    this.campusStatus,
  });

  final String name;

  /// "Software Engineering (4BI) · ESPRIT Ghazela" (null while loading).
  final String? programLine;

  /// "On Campus: Ghazela Technopark"; shows the green dot when not null.
  final String? campusStatus;

  final VoidCallback onEdit;

  /// Null hides the button (teachers, admins, alumni and companies have no student pass).
  final VoidCallback? onNfcPass;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final programLine = this.programLine;

    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: _bannerHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppColors.hero,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            _bannerHeight - _avatarOverlap,
            AppSpacing.page,
            0,
          ),
          child: Column(
            children: [
              _Avatar(name: name, campusStatus: campusStatus),
              const SizedBox(height: AppSpacing.sm),
              Text(
                name,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontSize: 24,
                  height: 32 / 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.36,
                ),
              ),
              if (programLine != null) ...[
                const SizedBox(height: AppSpacing.xs),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Text(
                    programLine,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
              if (onNfcPass != null) ...[
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: onNfcPass,
                  icon: const Icon(Icons.contactless_outlined, size: 18),
                  label: const Text('NFC Student Pass'),
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.secondary,
                    foregroundColor: scheme.onSecondary,
                    // The theme's Size.fromHeight(52) would stretch it full width.
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.sm + 2,
                    ),
                    shape: const StadiumBorder(),
                    elevation: 3,
                    shadowColor: scheme.secondary.withValues(alpha: 0.5),
                    textStyle: theme.textTheme.labelLarge?.copyWith(letterSpacing: 0.4),
                  ),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          top: AppSpacing.lg,
          right: AppSpacing.lg,
          child: _EditPill(onTap: onEdit),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.campusStatus});

  final String name;
  final String? campusStatus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = campusStatus;
    return SizedBox.square(
      dimension: _avatarSize,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: scheme.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            // Initials instead of a photo; scaled up from the shared avatar.
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: FittedBox(child: UserAvatar(name: name)),
            ),
          ),
          if (status != null)
            Positioned(
              right: AppSpacing.xs,
              bottom: AppSpacing.xs,
              child: Tooltip(
                message: status,
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: scheme.surface, shape: BoxShape.circle),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EditPill extends StatelessWidget {
  const _EditPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.2),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.edit_outlined, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                'Edit',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
