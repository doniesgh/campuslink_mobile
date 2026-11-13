import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/entities/job.dart';
import '../../domain/entities/job_summary.dart';
import '../providers/job_providers.dart';

/// Opens the AI summary of [job] in a bottom sheet.
Future<void> showJobSummarySheet(BuildContext context, Job job) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => JobSummarySheet(job: job),
    );

/// What to tell the user when the summary failed: the AI codes of the
/// server (docs/api.md) explained, otherwise the server's own message.
String jobSummaryErrorText(Object error) {
  if (error is! Failure) return failureMessage(error);
  return switch (error.code) {
    'AI_UNAVAILABLE' => 'AI summaries are not set up on this server yet (no AI key is '
        'configured). The full offer is still below.',
    'AI_NO_CREDITS' => 'The AI service has no credits left for now. Try again later.',
    'AI_BUSY' => 'The AI service is busy right now. Try again in a few minutes.',
    'AI_FAILED' => 'The AI service could not answer. Try again.',
    'TOO_MANY_REQUESTS' => 'You asked for too many summaries. '
        'Try again ${_inMinutes(error is TooManyRequestsFailure ? error.retryAfter : null)}.',
    _ => error.message,
  };
}

String _inMinutes(Duration? wait) {
  if (wait == null) return 'later';
  final minutes = (wait.inSeconds / 60).ceil();
  return minutes <= 1 ? 'in a minute' : 'in $minutes minutes';
}

/// Retrying won't help until the server is set up.
bool _canRetry(Object error) => !(error is Failure && error.code == 'AI_UNAVAILABLE');

/// The AI summary of an offer: loading, then the summary, key points,
/// skills and "ideal for", or an explained error.
class JobSummarySheet extends ConsumerWidget {
  const JobSummarySheet({super.key, required this.job});

  final Job job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final summary = ref.watch(jobSummaryProvider(job.id));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page, 0, AppSpacing.page, AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: scheme.secondary),
              const SizedBox(width: AppSpacing.sm),
              Text('AI summary', style: theme.textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            job.title,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          summary.when(
            loading: () => const _Loading(),
            error: (e, _) => _Error(
              error: e,
              onRetry: _canRetry(e) ? () => ref.invalidate(jobSummaryProvider(job.id)) : null,
            ),
            data: (s) => _Summary(summary: s),
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: AppSpacing.md),
              Text('Summarising the offer…'),
            ],
          ),
        ),
      );
}

class _Error extends StatelessWidget {
  const _Error({required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: scheme.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(jobSummaryErrorText(error))),
          ],
        ),
        if (onRetry != null) ...[
          const SizedBox(height: AppSpacing.lg),
          AppButton(label: 'Retry', variant: AppButtonVariant.outlined, onPressed: onRetry),
        ],
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.summary});

  final JobSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
          child: Text(text, style: theme.textTheme.titleSmall),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(summary.summary, style: theme.textTheme.bodyMedium),
        if (summary.keyPoints.isNotEmpty) ...[
          heading('Key points'),
          for (final point in summary.keyPoints)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: Text(point, style: theme.textTheme.bodySmall)),
                ],
              ),
            ),
        ],
        if (summary.skills.isNotEmpty) ...[
          heading('Skills'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [for (final s in summary.skills) AppBadge(s, tone: BadgeTone.primary)],
          ),
        ],
        if (summary.idealFor.isNotEmpty) ...[
          heading('Ideal for'),
          Text(summary.idealFor, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(
          'AI-generated: check the full offer.'
          '${summary.model.isEmpty ? '' : ' · ${summary.model}'}',
          style: theme.textTheme.labelSmall?.copyWith(color: muted),
        ),
      ],
    );
  }
}
