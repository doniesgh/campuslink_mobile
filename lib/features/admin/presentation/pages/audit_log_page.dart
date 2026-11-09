import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/providers/clock_provider.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/detail_top_bar.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/audit_entry.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_widgets.dart';

/// "Created", "Updated"... for an action such as "user.create"; the action
/// itself for one this app doesn't know yet.
String auditActionLabel(String action) => switch (action) {
      'user.create' => 'Created',
      'user.update' => 'Updated',
      'user.delete' => 'Deleted',
      'user.import' => 'Imported',
      _ => action,
    };

IconData auditActionIcon(String action) => switch (action) {
      'user.create' => Icons.person_add_alt_1_outlined,
      'user.update' => Icons.manage_accounts_outlined,
      'user.delete' => Icons.person_remove_outlined,
      'user.import' => Icons.upload_file_outlined,
      _ => Icons.history,
    };

/// Administration › Audit log: every change made by an admin, newest first,
/// filtered by action.
class AuditLogPage extends ConsumerStatefulWidget {
  const AuditLogPage({super.key});

  @override
  ConsumerState<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends ConsumerState<AuditLogPage> {
  /// Null: every action.
  String? _action;

  Future<void> _refresh() async {
    ref.invalidate(auditActionsProvider);
    ref.invalidate(auditListProvider(_action));
    try {
      await ref.read(auditListProvider(_action).future);
    } catch (_) {
      // The list shows its own error.
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = ref.watch(auditActionsProvider).valueOrNull ?? const <String>[];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, 0),
              child: DetailTopBar(backLabel: 'Users', fallbackPath: RoutePaths.adminUsers),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.page, AppSpacing.lg, AppSpacing.page, AppSpacing.sm,
              ),
              child: AdminTitle(
                title: 'Audit log',
                subtitle: 'Every change made by an admin, newest first.',
              ),
            ),
            FilterChipBar<String?>(
              selected: _action,
              onSelected: (action) => setState(() => _action = action),
              options: [
                (null, 'All', null, null),
                for (final action in actions)
                  (action, auditActionLabel(action), auditActionIcon(action), null),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(child: _list()),
          ],
        ),
      ),
    );
  }

  Widget _list() {
    final action = _action;
    final async = ref.watch(auditListProvider(action));
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    return async.when(
      skipLoadingOnRefresh: true,
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(
        message: failureMessage(e),
        onRetry: () => ref.invalidate(auditListProvider(action)),
      ),
      data: (list) {
        if (list.items.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: AppSpacing.huge),
                EmptyView(icon: Icons.history, message: 'Nothing recorded yet.'),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page, 0, AppSpacing.page, AppSpacing.xl,
            ),
            itemCount: list.items.length + 1,
            itemBuilder: (context, i) {
              if (i == list.items.length) {
                return PagedListFooter(
                  isLoading: list.isLoadingMore,
                  error: list.loadMoreError,
                  onRetry: ref.read(auditListProvider(action).notifier).loadMore,
                );
              }
              if (i >= list.items.length - 4 && list.hasMore && list.loadMoreError == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) ref.read(auditListProvider(action).notifier).loadMore();
                });
              }
              final entry = list.items[i];
              final target = entry.targetId;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AuditEntryCard(
                  entry: entry,
                  now: now,
                  // A deleted account has nothing left to open.
                  onTap: target == null || entry.action == 'user.delete'
                      ? null
                      : () => context.push(RoutePaths.adminUser(target)),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// One audit entry: what happened, who did it and when.
class AuditEntryCard extends StatelessWidget {
  const AuditEntryCard({super.key, required this.entry, required this.now, this.onTap});

  final AuditEntry entry;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final actor = entry.actorName ?? entry.actorEmail ?? 'System';
    final ip = entry.ip;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(auditActionIcon(entry.action), size: 18, color: scheme.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.summary, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'By $actor · ${formatTimeAgo(entry.createdAt, now: now)}'
                  '${ip == null ? '' : ' · $ip'}',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (onTap != null) Icon(Icons.chevron_right, color: scheme.outline),
        ],
      ),
    );
  }
}
