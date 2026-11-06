import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../domain/entities/forum_post.dart';
import '../utils/idea_formatters.dart';
import '../utils/lost_found_formatters.dart';

/// An idea of the forum "Ideas" section: author, theme badge, text, upvote
/// button, comment count and BDE status.
class IdeaCard extends StatelessWidget {
  const IdeaCard({
    super.key,
    required this.idea,
    required this.upvote,
    required this.now,
    required this.onUpvote,
  });

  final ForumPost idea;

  /// Count and state to show (with this session's votes applied).
  final IdeaUpvote upvote;
  final DateTime now;
  final VoidCallback onUpvote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = idea.status;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(name: idea.authorName),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      idea.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      '${idea.authorInfo} · ${formatLostItemTime(idea.postedAt, now: now)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: AppBadge(
                  idea.tag,
                  tone: BadgeTone.accent,
                  icon: Icons.tips_and_updates_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(idea.body, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              IdeaUpvoteButton(upvote: upvote, onTap: onUpvote),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  ideaCommentsLabel(idea.comments),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              if (status != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Flexible(child: AppBadge(status, tone: BadgeTone.success)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Thumb-up pill with the vote count, highlighted once the student voted.
class IdeaUpvoteButton extends StatelessWidget {
  const IdeaUpvoteButton({super.key, required this.upvote, required this.onTap});

  final IdeaUpvote upvote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final voted = upvote.isUpvotedByMe;
    final (bg, fg) = voted
        ? toneColors(scheme, BadgeTone.accent)
        : (scheme.surfaceContainer, scheme.primary);

    return Semantics(
      // Its own node: not merged into the card's text.
      container: true,
      button: true,
      toggled: voted,
      label: ideaUpvoteSemantics(upvote.upvotes, isUpvotedByMe: voted),
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: bg,
        borderRadius: AppRadius.mdAll,
        child: InkWell(
          borderRadius: AppRadius.mdAll,
          onTap: onTap,
          child: ConstrainedBox(
            // Comfortable touch target.
            constraints: const BoxConstraints(minHeight: 36, minWidth: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    voted ? Icons.thumb_up : Icons.thumb_up_outlined,
                    size: 15,
                    color: voted ? fg : scheme.secondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${upvote.upvotes}',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: fg, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
