import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/bottom_action_bar.dart';
import '../../../../shared/widgets/detail_top_bar.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/domain/entities/user.dart';
import '../../domain/entities/job.dart';
import '../../domain/entities/job_application.dart';
import '../providers/job_providers.dart';
import '../widgets/job_detail_sections.dart';
import '../widgets/job_summary_sheet.dart';

/// "Job Detail & Application" screen. Its author and admins also get Edit
/// and Delete; everyone gets the AI summary.
class JobDetailPage extends ConsumerStatefulWidget {
  const JobDetailPage({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends ConsumerState<JobDetailPage> {
  bool _saved = false;
  bool _applying = false;
  bool _cancelling = false;
  bool _deleting = false;

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _share(Job job) async {
    await Clipboard.setData(ClipboardData(text: 'campuspulse://jobs/${job.id}'));
    if (mounted) _snack('Link copied');
  }

  Future<void> _apply(Job job) async {
    setState(() => _applying = true);
    final result = await ref.read(jobRepositoryProvider).apply(job.id);
    if (!mounted) return;
    setState(() => _applying = false);
    result.when(
      success: (_) {
        // The list shows an "Applied" badge too.
        ref.invalidate(jobsProvider);
        ref.invalidate(jobDetailProvider(job.id));
        ref.invalidate(myApplicationsProvider);
        _snack('Application sent to ${job.company}');
      },
      failure: (f) => _snack(f.message),
    );
  }

  Future<void> _cancelApplication(Job job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel your application?'),
        content: Text('Your application to "${job.title}" will be withdrawn.'),
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
    setState(() => _cancelling = true);
    final result = await ref.read(jobRepositoryProvider).cancelApplication(job.id);
    if (!mounted) return;
    setState(() => _cancelling = false);
    // Success or not (it may have been answered meanwhile), show the real state.
    ref.invalidate(jobsProvider);
    ref.invalidate(jobDetailProvider(job.id));
    ref.invalidate(myApplicationsProvider);
    result.when(
      success: (_) => _snack('Application cancelled'),
      failure: (f) => _snack(f.message),
    );
  }

  Future<void> _delete(Job job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this offer?'),
        content: Text(
          '"${job.title}" will be removed for every student, with its applications. '
          "This can't be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    final result = await ref.read(jobRepositoryProvider).deleteJob(job.id);
    if (!mounted) return;
    setState(() => _deleting = false);
    result.when(
      success: (_) {
        ref.invalidate(jobsProvider);
        _snack('Offer deleted');
        context.canPop() ? context.pop() : context.go(RoutePaths.jobs);
      },
      failure: (f) => _snack(f.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(jobDetailProvider(widget.jobId));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: failureMessage(e),
            onRetry: () => ref.invalidate(jobDetailProvider(widget.jobId)),
          ),
          data: _buildContent,
        ),
      ),
    );
  }

  Widget _buildContent(Job job) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final applied = job.hasApplied;
    final status = job.applicationStatus ?? ApplicationStatus.pending;
    // The API says so; an admin may manage every offer (the mock can't tell).
    final canManage = job.canEdit || ref.watch(jobsRoleProvider) == UserRole.admin;
    final canApply = ref.watch(canApplyToJobsProvider);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.lg,
            ),
            children: [
              DetailTopBar(
                backLabel: 'Opportunities',
                fallbackPath: RoutePaths.jobs,
                trailing: [
                  IconButton(
                    tooltip: 'Save',
                    icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_border),
                    color: scheme.primary,
                    onPressed: () => setState(() => _saved = !_saved),
                  ),
                  IconButton(
                    tooltip: 'Share',
                    icon: const Icon(Icons.share_outlined),
                    color: scheme.primary,
                    onPressed: () => _share(job),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              JobHeaderCard(job: job),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'AI summary',
                icon: Icons.auto_awesome,
                variant: AppButtonVariant.outlined,
                onPressed: () => showJobSummarySheet(context, job),
              ),
              if (canManage) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Edit',
                        icon: Icons.edit_outlined,
                        variant: AppButtonVariant.outlined,
                        onPressed: () => context.push(RoutePaths.editJob(job.id)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
                        icon: _deleting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                        onPressed: _deleting ? null : () => _delete(job),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Applications',
                  icon: Icons.people_outline,
                  variant: AppButtonVariant.outlined,
                  onPressed: () => context.push(RoutePaths.jobApplications(job.id)),
                ),
              ],
              if (JobStatsRow.hasStats(job)) ...[
                const SizedBox(height: AppSpacing.md),
                JobStatsRow(job: job),
              ],
              if (job.workspaceTitle != null) ...[
                const SizedBox(height: AppSpacing.md),
                JobWorkspaceBanner(job: job),
              ],
              const SizedBox(height: AppSpacing.md),
              JobMissionCard(job: job),
              if (JobFitCard.hasContent(job)) ...[
                const SizedBox(height: AppSpacing.md),
                JobFitCard(job: job),
              ],
            ],
          ),
        ),
        BottomActionBar(
          leading: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                job.matchPercent == null ? 'POSTED BY' : 'PROFILE MATCH',
                style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              Text(
                job.matchPercent == null ? job.company : '${job.matchPercent}%',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: job.matchPercent == null
                    ? theme.textTheme.titleSmall
                    : theme.textTheme.titleLarge,
              ),
            ],
          ),
          action: canApply
              ? (applied
                  // Pending: the student can still withdraw. Answered: just the status.
                  ? (status == ApplicationStatus.pending
                      ? AppButton(
                          label: 'Cancel application',
                          icon: Icons.close,
                          variant: AppButtonVariant.outlined,
                          isLoading: _cancelling,
                          onPressed: () => _cancelApplication(job),
                        )
                      : AppButton(
                          label: status.label,
                          icon: status == ApplicationStatus.accepted ? Icons.check : Icons.block,
                          variant: AppButtonVariant.outlined,
                          onPressed: null,
                        ))
                  : AppButton(
                      label: 'Apply Now',
                      icon: Icons.send_rounded,
                      variant: AppButtonVariant.accent,
                      isLoading: _applying,
                      onPressed: () => _apply(job),
                    ))
              : const AppButton(
                  label: 'Students apply',
                  icon: Icons.school_outlined,
                  variant: AppButtonVariant.outlined,
                  onPressed: null,
                ),
        ),
      ],
    );
  }
}
