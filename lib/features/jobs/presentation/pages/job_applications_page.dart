import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Applications received by one offer (its company, or an admin): Accept or
/// Refuse each pending one.
class JobApplicationsPage extends ConsumerStatefulWidget {
  const JobApplicationsPage({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<JobApplicationsPage> createState() => _JobApplicationsPageState();
}

class _JobApplicationsPageState extends ConsumerState<JobApplicationsPage> {
  String? _busy;

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _decide(JobApplication application, {required bool accept}) async {
    setState(() => _busy = application.id);
    final result = await ref
        .read(jobRepositoryProvider)
        .decideApplication(widget.jobId, application.id, accept: accept);
    if (!mounted) return;
    setState(() => _busy = null);
    ref.invalidate(jobApplicationsProvider(widget.jobId));
    result.when(
      success: (_) => _snack(
        accept
            ? '${application.applicantName} accepted'
            : '${application.applicantName} refused',
      ),
      failure: (f) => _snack(f.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final applications = ref.watch(jobApplicationsProvider(widget.jobId));
    final job = ref.watch(jobDetailProvider(widget.jobId)).valueOrNull;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, 0),
              child: DetailTopBar(
                backLabel: 'Offer',
                fallbackPath: RoutePaths.job(widget.jobId),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Applications', style: Theme.of(context).textTheme.titleLarge),
                    if (job != null)
                      Text(
                        job.title,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: applications.when(
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(
                  message: failureMessage(e),
                  onRetry: () => ref.invalidate(jobApplicationsProvider(widget.jobId)),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const EmptyView(message: 'No applications for this offer yet.');
                  }
                  return RefreshIndicator(
                    onRefresh: () async => ref.refresh(jobApplicationsProvider(widget.jobId).future),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page, 0, AppSpacing.page, AppSpacing.xl,
                      ),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                      itemBuilder: (_, i) => _ApplicantCard(
                        application: list[i],
                        busy: _busy == list[i].id,
                        onAccept: () => _decide(list[i], accept: true),
                        onRefuse: () => _decide(list[i], accept: false),
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

class _ApplicantCard extends StatelessWidget {
  const _ApplicantCard({
    required this.application,
    required this.busy,
    required this.onAccept,
    required this.onRefuse,
  });

  final JobApplication application;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = application.applicantName.isEmpty ? 'Unknown student' : application.applicantName;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              JobLogo(initials: name.substring(0, 1).toUpperCase(), size: 44),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.titleSmall),
                    if (application.applicantEmail.isNotEmpty)
                      Text(
                        application.applicantEmail,
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
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
                    icon: const Icon(Icons.close),
                    label: const Text('Refuse'),
                    onPressed: busy ? null : onRefuse,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Accept'),
                    onPressed: busy ? null : onAccept,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
