import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../providers/admin_providers.dart';

/// "Administration" on the Profile tab of admins: Users, Import, Timetable, Audit log.
class AdministrationSection extends ConsumerWidget {
  const AdministrationSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = ref.watch(userStatsProvider).valueOrNull?.total;
    final chevron = Icon(Icons.chevron_right, size: 18, color: scheme.outline);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text(
            'Administration',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              _AdminRow(
                icon: Icons.manage_accounts_outlined,
                title: 'Users',
                subtitle: 'Accounts, roles and passwords',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (total != null) ...[
                      AppBadge('$total', tone: BadgeTone.primary),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    chevron,
                  ],
                ),
                onTap: () => context.push(RoutePaths.adminUsers),
              ),
              _AdminRow(
                icon: Icons.upload_file_outlined,
                title: 'Import accounts',
                subtitle: 'From a CSV file or a spreadsheet',
                trailing: chevron,
                onTap: () => context.push(RoutePaths.importUsers),
              ),
              _AdminRow(
                icon: Icons.calendar_month_outlined,
                title: 'Timetable',
                subtitle: 'Weekly classes, rooms and online sessions',
                trailing: chevron,
                onTap: () => context.push(RoutePaths.adminTimetable),
              ),
              _AdminRow(
                icon: Icons.history,
                title: 'Audit log',
                subtitle: 'Every change made by an admin',
                trailing: chevron,
                onTap: () => context.push(RoutePaths.auditLog),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminRow extends StatelessWidget {
  const _AdminRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (iconBg, iconFg) = toneColors(scheme, BadgeTone.primary);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
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
                      style: theme.textTheme.titleMedium,
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
        ),
      ),
    );
  }
}
