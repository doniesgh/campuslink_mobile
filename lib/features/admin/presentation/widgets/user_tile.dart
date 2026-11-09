import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../domain/entities/managed_user.dart';
import 'admin_widgets.dart';

/// One account in the Users list: initials, name, email, role and ENT ID.
class UserTile extends StatelessWidget {
  const UserTile({super.key, required this.user, required this.isYou, required this.onTap});

  final ManagedUser user;

  /// The admin's own account ("(you)").
  final bool isYou;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final studentId = user.studentId;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(name: user.displayName, radius: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isYou ? '${user.displayName} (you)' : user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs + 2,
                  runSpacing: AppSpacing.xs + 2,
                  children: [
                    RoleBadge(user.role),
                    if (studentId != null)
                      AppBadge(studentId, tone: BadgeTone.neutral, icon: Icons.badge_outlined),
                    if (!user.isEmailVerified)
                      const AppBadge(
                        'Email not verified',
                        tone: BadgeTone.accent,
                        icon: Icons.mark_email_unread_outlined,
                      ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: scheme.outline),
        ],
      ),
    );
  }
}
