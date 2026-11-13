import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/detail_top_bar.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/job_application.dart';
import '../providers/job_providers.dart';
import '../widgets/application_status_badge.dart';
import '../widgets/job_logo.dart';

/// "My applications" (students): every offer the student applied to, with its
/// status, and a Cancel button while the company hasn't answered.
class MyApplicationsPage extends ConsumerStatefulWidget {
  const MyApplicationsPage({super.key});

  @override
  ConsumerState<MyApplicationsPage> createState() => _MyApplicationsPageState();
}

class _MyApplicationsPageState extends ConsumerState<MyApplicationsPage> {
  String? _cancelling;

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _cancel(JobApplication application) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this application?'),
        content: Text(
          'Your application to "${application.jobTitle}" at ${application.company} '
          'will be withdrawn. You can apply again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel application'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = application.id);
    final result = await ref.read(jobRepositoryProvider).cancelApplication(application.jobId);
    if (!mounted) return;
    setState(() => _cancelling = null);
    result.when(
      success: (_) {
        ref.invalidate(myApplicationsProvider);
        ref.invalidate(jobsProvider);
        ref.invalidate(jobDetailProvider(application.jobId));
        _snack('Application cancelled');
      },
      failure: (f) {
        // Probably answered in the meantime: show the fresh status.
        ref.invalidate(myApplicationsProvider);
        _snack(f.message);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final applications = ref.watch(myApplicationsProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, 0),
              child: DetailTopBar(backLabel: 'Jobs', fallbackPath: RoutePaths.jobs),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('My applications', style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            Expanded(
              child: applications.when(
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(
                  message: failureMessage(e),
                  onRetry: () => ref.invalidate(myApplicationsProvider),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const EmptyView(message: "You haven't applied to any offer yet.");
                  }
                  return RefreshIndicator(
                    onRefresh: () async => ref.refresh(myApplicationsProvider.future),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page, 0, AppSpacing.page, AppSpacing.xl,
                      ),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                      itemBuilder: (_, i) => _ApplicationCard(
                        application: list[i],
                        cancelling: _cancelling == list[i].id,
                        onOpen: () => context.push(RoutePaths.job(list[i].jobId)),
                        onCancel: () => _cancel(list[i]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.application,
    required this.cancelling,
    required this.onOpen,
    required this.onCancel,
  });

  final JobApplication application;
  final bool cancelling;
  final VoidCallback onOpen;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final initials = application.company.trim().isEmpty
        ? '?'
        : application.company.trim().substring(0, 1).toUpperCase();
    return AppCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              JobLogo(initials: initials, size: 44),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(application.jobTitle, style: theme.textTheme.titleSmall),
                    Text(
                      application.companyLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              ApplicationStatusBadge(application.status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Applied on ${application.appliedOn}',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (application.isPending) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
                icon: cancelling
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.close),
                label: const Text('Cancel application'),
                onPressed: cancelling ? null : onCancel,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
