import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_snack.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../forum/domain/entities/forum_post.dart';
import '../../../forum/presentation/providers/forum_providers.dart';

/// Forum post in the Home "Campus Highlights" feed.
class HighlightPostCard extends StatelessWidget {
  const HighlightPostCard({
    super.key,
    required this.post,
    required this.now,
    required this.onOpen,
  });

  final ForumPost post;
  final DateTime now;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (IconData tagIcon, BadgeTone tone, bool solid) = switch (post.category) {
      PostCategory.carpool => (Icons.directions_car, BadgeTone.accent, true),
      PostCategory.lostFound => (Icons.search, BadgeTone.primary, false),
      PostCategory.idea => (Icons.tips_and_updates_outlined, BadgeTone.accent, false),
    };

    return AppCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(name: post.authorName),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      '${post.authorInfo} · ${formatTimeAgo(post.postedAt, now: now)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppBadge(post.tag, tone: tone, solid: solid, icon: tagIcon),
            ],
          ),
          const SizedBox(height: 10),
          Text(post.body, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          if (post.category == PostCategory.idea)
            _IdeaFooter(post: post)
          else
            _PlaceFooter(post: post, onOpen: onOpen),
        ],
      ),
    );
  }
}

/// Route/location chip + quick reply action (covoiturage, lost & found).
class _PlaceFooter extends StatelessWidget {
  const _PlaceFooter({required this.post, required this.onOpen});

  final ForumPost post;

  /// Opens the post's Forum section (Lost & Found has the real claim flow).
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final carpool = post.category == PostCategory.carpool;
    final place = post.place;
    return Row(
      children: [
        Expanded(
          child: place == null
              ? const SizedBox.shrink()
              : Align(
                  alignment: Alignment.centerLeft,
                  child: _PlaceChip(
                    icon: carpool ? Icons.route : Icons.location_on_outlined,
                    iconColor: carpool ? scheme.secondary : scheme.primary,
                    label: place,
                  ),
                ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // TODO: open a conversation with the driver once messaging exists.
        carpool
            ? _PillButton(
                icon: Icons.chat_bubble_outline,
                label: 'Répondre',
                onTap: () => showAppSnack(context, 'Messaging is coming soon.'),
              )
            : _PillButton(
                icon: Icons.check,
                label: "C'est à moi",
                onTap: onOpen,
              ),
      ],
    );
  }
}

/// Upvote button, comment count and moderation status (ideas).
/// The vote is shared with the Forum's Ideas section (same count on both screens).
class _IdeaFooter extends ConsumerWidget {
  const _IdeaFooter({required this.post});

  final ForumPost post;

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final failure = await ref.read(ideaUpvotesProvider.notifier).toggle(post);
    if (failure != null && context.mounted) showAppSnack(context, failure.message);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final status = post.status;
    final vote = ref.watch(ideaUpvotesProvider)[post.id] ?? post.upvote;
    return Row(
      children: [
        _PillButton(
          icon: Icons.thumb_up,
          label: '${vote.upvotes}',
          highlighted: vote.isUpvotedByMe,
          onTap: () => _toggle(context, ref),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            '${post.comments} commentaires',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        if (status != null) AppBadge(status, tone: BadgeTone.success),
      ],
    );
  }
}

class _PlaceChip extends StatelessWidget {
  const _PlaceChip({required this.icon, required this.iconColor, required this.label});

  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.smAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (bg, fg) = highlighted
        ? toneColors(scheme, BadgeTone.accent)
        : (scheme.surfaceContainer, scheme.primary);
    return Material(
      color: bg,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        borderRadius: AppRadius.mdAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: highlighted ? fg : scheme.secondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
