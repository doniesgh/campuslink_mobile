import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/providers/clock_provider.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_snack.dart';
import '../../../../shared/widgets/bottom_action_bar.dart';
import '../../../../shared/widgets/detail_top_bar.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/forum_post.dart';
import '../providers/forum_providers.dart';
import '../utils/lost_found_formatters.dart';

/// Full detail view for a single idea. Shows delete if the idea belongs to
/// the signed-in student ([ForumPost.isMine]).
class IdeaDetailPage extends ConsumerStatefulWidget {
  const IdeaDetailPage({super.key, required this.ideaId});

  final String ideaId;

  @override
  ConsumerState<IdeaDetailPage> createState() => _IdeaDetailPageState();
}

class _IdeaDetailPageState extends ConsumerState<IdeaDetailPage> {
  bool _deleting = false;

  Future<void> _upvote(ForumPost idea) async {
    final failure = await ref.read(ideaUpvotesProvider.notifier).toggle(idea);
    if (failure != null && mounted) showAppSnack(context, failure.message);
  }

  Future<void> _confirmDelete(ForumPost idea) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette idée ?'),
        content: const Text(
          'Cette action est irréversible. Votre idée et ses votes seront définitivement supprimés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    final error = await deleteIdea(ref, idea.id);
    if (!mounted) return;
    setState(() => _deleting = false);

    if (error != null) {
      showAppSnack(context, error);
    } else {
      Navigator.of(context).pop();
      showAppSnack(context, 'Idée supprimée.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Look up the idea from the cached list; fall back gracefully.
    final ideasAsync = ref.watch(ideasProvider);
    final votes = ref.watch(ideaUpvotesProvider);
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ideasAsync.when(
          skipLoadingOnReload: true,
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: failureMessage(e),
            onRetry: () => ref.invalidate(ideasProvider),
          ),
          data: (all) {
            final idea = all.cast<ForumPost?>().firstWhere(
                  (p) => p?.id == widget.ideaId,
                  orElse: () => null,
                );
            if (idea == null) {
              return const ErrorView(message: "Cette idée n'existe plus.");
            }
            final upvote = votes[idea.id] ?? idea.upvote;
            return _IdeaDetailContent(
              idea: idea,
              upvote: upvote,
              now: now,
              deleting: _deleting,
              onUpvote: () => _upvote(idea),
              onDelete: idea.isMine ? () => _confirmDelete(idea) : null,
            );
          },
        ),
      ),
    );
  }
}

class _IdeaDetailContent extends StatelessWidget {
  const _IdeaDetailContent({
    required this.idea,
    required this.upvote,
    required this.now,
    required this.deleting,
    required this.onUpvote,
    required this.onDelete,
  });

  final ForumPost idea;
  final IdeaUpvote upvote;
  final DateTime now;
  final bool deleting;
  final VoidCallback onUpvote;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.md,
              AppSpacing.page,
              AppSpacing.lg + (onDelete != null ? 0 : MediaQuery.paddingOf(context).bottom),
            ),
            children: [
              DetailTopBar(
                backLabel: 'Retour au Forum',
                fallbackPath: '/app/forum',
                trailing: [
                  Flexible(child: AppBadge(idea.tag, tone: BadgeTone.accent)),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              // Status pill
              if (idea.status != null) ...[
                _StatusPill(status: idea.status!),
                const SizedBox(height: AppSpacing.md),
              ],
              // Body
              Text(idea.body, style: theme.textTheme.bodyLarge),
              const SizedBox(height: AppSpacing.lg),
              // Author row
              _AuthorRow(authorName: idea.authorName, authorInfo: idea.authorInfo, now: now, postedAt: idea.postedAt),
              const SizedBox(height: AppSpacing.lg),
              // Upvote card
              _UpvoteCard(upvote: upvote, onUpvote: onUpvote),
            ],
          ),
        ),
        if (onDelete != null)
          BottomActionBar(
            leading: Text(
              'Votre idée',
              style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            action: AppButton(
              label: 'Supprimer',
              icon: Icons.delete_outline,
              variant: AppButtonVariant.outlined,
              isLoading: deleting,
              onPressed: onDelete,
            ),
          ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.how_to_vote_outlined, size: 14, color: scheme.onSecondaryContainer),
          const SizedBox(width: 6),
          Text(
            status,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: scheme.onSecondaryContainer, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({
    required this.authorName,
    required this.authorInfo,
    required this.now,
    required this.postedAt,
  });

  final String authorName;
  final String authorInfo;
  final DateTime now;
  final DateTime postedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: scheme.surfaceContainerHigh,
          child: Text(
            authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
            style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(authorName, style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
              Text(
                '$authorInfo · ${formatLostItemTime(postedAt, now: now)}',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UpvoteCard extends StatelessWidget {
  const _UpvoteCard({required this.upvote, required this.onUpvote});
  final IdeaUpvote upvote;
  final VoidCallback onUpvote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final active = upvote.isUpvotedByMe;
    return Material(
      color: active ? scheme.primaryContainer : scheme.surfaceContainer,
      borderRadius: AppRadius.lgAll,
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        onTap: onUpvote,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(
            children: [
              Icon(
                active ? Icons.thumb_up : Icons.thumb_up_outlined,
                size: 20,
                color: active ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${upvote.upvotes} vote${upvote.upvotes == 1 ? '' : 's'}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: active ? scheme.onPrimaryContainer : scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                active ? 'Vous avez voté ✓' : 'Voter pour cette idée',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: active ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
