import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../domain/entities/course.dart';
import '../utils/course_formatters.dart';

/// "Course Community & Helpdesk" card with the online classmates' avatars.
class CommunityCard extends StatelessWidget {
  const CommunityCard({super.key, required this.community, required this.onTap});

  final CourseCommunity community;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: scheme.surfaceContainer, shape: BoxShape.circle),
                child: Icon(Icons.forum_outlined, size: 22, color: scheme.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Course Community & Helpdesk',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      classmatesOnlineLabel(community.onlineCount),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (community.onlineClassmates.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.md),
                _AvatarStack(names: community.onlineClassmates, ringColor: scheme.surfaceContainerLow),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Two overlapping avatars and a "+8" bubble.
class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.names, required this.ringColor});

  final List<String> names;
  final Color ringColor;

  static const _maxShown = 2;
  static const _avatar = 28.0;
  static const _ring = 2.0;
  static const _overlap = 8.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shown = names.take(_maxShown).toList();
    final extra = names.length - shown.length;
    final bubbles = <Widget>[
      for (final name in shown) UserAvatar(name: name, radius: _avatar / 2),
      if (extra > 0)
        CircleAvatar(
          radius: _avatar / 2,
          backgroundColor: scheme.primaryContainer,
          child: Text(
            '+$extra',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800),
          ),
        ),
    ];
    const outer = _avatar + 2 * _ring;
    const step = outer - _overlap;
    // Decorative and fixed-size: the count is already in the subtitle.
    return ExcludeSemantics(
      child: MediaQuery.withNoTextScaling(
        child: SizedBox(
          width: outer + step * (bubbles.length - 1),
          height: outer,
          child: Stack(
            children: [
              for (var i = 0; i < bubbles.length; i++)
                Positioned(
                  left: step * i,
                  child: Container(
                    padding: const EdgeInsets.all(_ring),
                    decoration: BoxDecoration(color: ringColor, shape: BoxShape.circle),
                    child: bubbles[i],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
