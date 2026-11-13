import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../auth/domain/entities/user.dart';

/// Icon of each role, used in badges, chips and the role picker.
IconData roleIcon(UserRole role) => switch (role) {
      UserRole.student => Icons.school_outlined,
      UserRole.teacher => Icons.co_present_outlined,
      UserRole.admin => Icons.admin_panel_settings_outlined,
      UserRole.alumni => Icons.workspace_premium_outlined,
      UserRole.company => Icons.business_outlined,
    };

/// "Students", "Teachers"... for the filter chips.
String rolePlural(UserRole role) => switch (role) {
      UserRole.student => 'Students',
      UserRole.teacher => 'Teachers',
      UserRole.admin => 'Admins',
      UserRole.alumni => 'Alumni',
      UserRole.company => 'Companies',
    };

/// The role of an account. Admins stand out (solid purple).
class RoleBadge extends StatelessWidget {
  const RoleBadge(this.role, {super.key});

  final UserRole role;

  @override
  Widget build(BuildContext context) => AppBadge(
        role.label,
        icon: roleIcon(role),
        solid: role == UserRole.admin,
        tone: switch (role) {
          UserRole.admin || UserRole.student => BadgeTone.primary,
          UserRole.teacher => BadgeTone.accent,
          UserRole.alumni => BadgeTone.neutral,
          UserRole.company => BadgeTone.success,
        },
      );
}

/// Title and subtitle at the top of an admin screen.
class AdminTitle extends StatelessWidget {
  const AdminTitle({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// A horizontally scrolling row of filter chips with optional counts.
class FilterChipBar<T> extends StatelessWidget {
  const FilterChipBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  /// (value, label, icon, count). The count is left out when null.
  final List<(T, String, IconData?, int?)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: AppSpacing.xs),
        child: Row(
          children: [
            for (final (value, label, icon, count) in options)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: _Chip(
                  label: label,
                  icon: icon,
                  count: count,
                  selected: value == selected,
                  onTap: () => onSelected(value),
                ),
              ),
          ],
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (Color bg, Color fg) = selected
        ? (scheme.primary, scheme.onPrimary)
        : (scheme.surfaceContainer, scheme.onSurfaceVariant);
    final count = this.count;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: bg,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 15, color: fg),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w600),
                ),
                if (count != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: selected
                          ? scheme.onPrimary.withValues(alpha: 0.2)
                          : scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: selected ? scheme.onPrimary : scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// End of a list loaded page by page: a spinner while the next page loads,
/// a retry button when it failed, nothing otherwise.
class PagedListFooter extends StatelessWidget {
  const PagedListFooter({
    super.key,
    required this.isLoading,
    required this.error,
    required this.onRetry,
  });

  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    }
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          AppButton(label: 'Retry', onPressed: onRetry, variant: AppButtonVariant.outlined),
        ],
      ),
    );
  }
}

/// Asks before a destructive action. Resolves to true when confirmed.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(foregroundColor: scheme.error),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
