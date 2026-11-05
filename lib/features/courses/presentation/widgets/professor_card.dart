import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../domain/entities/course.dart';

/// Professor chip: avatar with online dot, name, office and an email button.
class ProfessorCard extends StatelessWidget {
  const ProfessorCard({super.key, required this.professor, required this.onEmail});

  final Professor professor;
  final VoidCallback onEmail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.lgAll,
      ),
      child: Row(
        children: [
          Semantics(
            label: professor.isOnline ? 'Online' : null,
            child: Stack(
              children: [
                UserAvatar(name: professor.name, radius: 22),
                if (professor.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.surfaceContainerLow, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  professor.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.meeting_room_outlined, size: 14, color: muted),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        professor.office,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: muted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            tooltip: 'Email ${professor.displayName}',
            onPressed: onEmail,
            icon: const Icon(Icons.mail_outline, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: scheme.surfaceContainer,
              foregroundColor: scheme.primary,
              fixedSize: const Size(40, 40),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
            ),
          ),
        ],
      ),
    );
  }
}
