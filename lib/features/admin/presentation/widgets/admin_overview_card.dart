import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../auth/domain/entities/user.dart';
import '../providers/admin_providers.dart';
import 'admin_widgets.dart';

/// On the Home tab of admins, where students see their next class: the
/// accounts by role, and the way into Administration.
class AdminOverviewCard extends ConsumerWidget {
  const AdminOverviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stats = ref.watch(userStatsProvider);
    final total = stats.valueOrNull?.total;

    return AppCard(
      onTap: () => context.go(RoutePaths.adminUsers),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: AppRadius.mdAll,
                ),
                child: Icon(Icons.admin_panel_settings_outlined, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Administration',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      total == null
                          ? 'Campus accounts'
                          : '$total account${total == 1 ? '' : 's'} on CampusPulse',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          stats.when(
            skipLoadingOnReload: true,
            loading: () => const SizedBox(
              height: 72,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
            ),
            error: (e, _) => Row(
              children: [
                Expanded(
                  child: Text(
                    failureMessage(e),
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
                  ),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(userStatsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
            data: (s) => Row(
              children: [
                for (final (i, role) in UserRole.values.indexed) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.sm),
                  Expanded(child: _RoleCount(role: role, count: s.count(role))),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go(RoutePaths.importUsers),
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('Import'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go(RoutePaths.auditLog),
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('Audit log'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleCount extends StatelessWidget {
  const _RoleCount({required this.role, required this.count});

  final UserRole role;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        children: [
          Icon(roleIcon(role), size: 18, color: scheme.primary),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$count',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(rolePlural(role), maxLines: 1, style: theme.textTheme.labelSmall),
          ),
        ],
      ),
    );
  }
}
