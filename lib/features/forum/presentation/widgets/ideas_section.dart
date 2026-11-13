import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/providers/clock_provider.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_snack.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/forum_post.dart';
import '../providers/forum_providers.dart';
import '../utils/idea_formatters.dart';
import 'idea_card.dart';

const _page = EdgeInsets.symmetric(horizontal: AppSpacing.page);

/// Content of the "Ideas" tab of the forum: the students' proposals, most
/// upvoted first. Votes are optimistic (see [ideaUpvotesProvider]).
class IdeasSection extends ConsumerWidget {
  const IdeasSection(
      {super.key, required this.query, required this.onClearSearch});

  /// Text typed in the forum search field.
  final String query;

  /// Empties the forum search field ("Réinitialiser la recherche").
  final VoidCallback onClearSearch;

  Future<void> _upvote(
      BuildContext context, WidgetRef ref, ForumPost idea) async {
    final failure = await ref.read(ideaUpvotesProvider.notifier).toggle(idea);
    if (failure != null && context.mounted)
      showAppSnack(context, failure.message);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ideas = ref.watch(ideasProvider);
    final votes = ref.watch(ideaUpvotesProvider);
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();

    return ideas.when(
      skipLoadingOnReload: true,
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(
        message: failureMessage(e),
        onRetry: () => ref.invalidate(ideasProvider),
      ),
      data: (all) {
        final visible = [
          for (final idea in all)
            if (idea.matches(query)) idea
        ];
        return RefreshIndicator(
          onRefresh: () => ref.read(ideasProvider.notifier).refresh(),
          child: ListView(
            // Scrollable even when short, so pull to refresh always works.
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(
                top: AppSpacing.xs, bottom: 96), // room for the FAB
            children: [
              Padding(padding: _page, child: _IdeasHeader(count: all.length)),
              const SizedBox(height: AppSpacing.lg),
              if (visible.isEmpty)
                Padding(
                  padding: _page,
                  child: all.isEmpty
                      ? const _NoIdeasView()
                      : _NoMatchView(onReset: onClearSearch),
                )
              else
                for (final idea in visible)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      0,
                      AppSpacing.page,
                      AppSpacing.md,
                    ),
                    child: IdeaCard(
                      key: ValueKey(idea.id),
                      idea: idea,
                      upvote: votes[idea.id] ?? idea.upvote,
                      now: now,
                      onUpvote: () => _upvote(context, ref, idea),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

/// BDE pill, idea count, title and subtitle.
class _IdeasHeader extends StatelessWidget {
  const _IdeasHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label =
        theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700);

  
return Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Idées du campus',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(width: AppSpacing.sm),
        Icon(
          Icons.lightbulb_outline,
          size: 18,
          color: scheme.secondary,
        ),
        const SizedBox(width: 4),
        Text(
          ideaCountLabel(count),
          style: label?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
    const SizedBox(height: 4),
    Text(
      'Proposez vos idées et votez pour celles que le BDE doit étudier en priorité',
      style: theme.textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),
  ],
);

  
  }
}

/// No idea published yet.
class _NoIdeasView extends StatelessWidget {
  const _NoIdeasView();

  @override
  Widget build(BuildContext context) => const _EmptyMessage(
        icon: Icons.tips_and_updates_outlined,
        title: "Aucune idée pour l'instant",
        message:
            'Soyez le premier à proposer une idée pour améliorer le campus !',
      );
}

/// Empty search result.
class _NoMatchView extends StatelessWidget {
  const _NoMatchView({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _EmptyMessage(
      icon: Icons.travel_explore,
      title: 'Aucune idée correspondante',
      message:
          'Essayez un autre mot-clé, ou proposez cette idée à la communauté.',
      action: TextButton(
        onPressed: onReset,
        style: TextButton.styleFrom(
          backgroundColor: scheme.surfaceContainer,
          foregroundColor: scheme.primary,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        ),
        child: const Text('Réinitialiser la recherche'),
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: scheme.surfaceContainerHigh,
            child: Icon(icon, size: 32, color: scheme.primary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(title,
              textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.lg),
            action!
          ],
        ],
      ),
    );
  }
}
