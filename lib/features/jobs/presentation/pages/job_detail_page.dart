import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/bottom_action_bar.dart';
import '../../../../shared/widgets/detail_top_bar.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/job.dart';
import '../providers/job_providers.dart';
import '../widgets/job_detail_sections.dart';

/// "Job Detail & Application" screen.
class JobDetailPage extends ConsumerStatefulWidget {
  const JobDetailPage({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends ConsumerState<JobDetailPage> {
  bool _saved = false;
  bool _applying = false;
  bool _applied = false;

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
        setState(() => _applied = true);
        _snack('Application sent to ${job.company}');
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
              JobStatsRow(job: job),
              const SizedBox(height: AppSpacing.md),
              JobWorkspaceBanner(job: job),
              const SizedBox(height: AppSpacing.md),
              JobMissionCard(job: job),
              const SizedBox(height: AppSpacing.md),
              JobFitCard(job: job),
            ],
          ),
        ),
        BottomActionBar(
          leading: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PROFILE MATCH',
                style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              Text('${job.matchPercent}%', style: theme.textTheme.titleLarge),
            ],
          ),
          action: AppButton(
            label: _applied ? 'Applied' : 'Apply Now',
            icon: _applied ? Icons.check : Icons.send_rounded,
            variant: AppButtonVariant.accent,
            isLoading: _applying,
            onPressed: _applied ? null : () => _apply(job),
          ),
        ),
      ],
    );
  }
}
