import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/providers/clock_provider.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../domain/entities/lost_item.dart';
import '../../domain/entities/lost_item_match.dart';
import '../providers/forum_providers.dart';
import '../utils/lost_found_formatters.dart';
import 'forum_sheet_parts.dart';
import 'lost_found_visuals.dart';

/// Opens the "Correspondances possibles" of [item]. Resolves to the match the
/// student tapped (to show it on the board), or null.
Future<LostItem?> showLostItemMatchesSheet(BuildContext context, LostItem item) =>
    showModalBottomSheet<LostItem>(
      context: context,
      // Above the bottom navigation bar, like the other Lost & Found sheets.
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      builder: (_) => LostItemMatchesSheet(item: item),
    );

/// Active notices of the other kind that may be the same object as [item],
/// best first, with their score and why (the AI's reason when it ranked them).
class LostItemMatchesSheet extends ConsumerWidget {
  const LostItemMatchesSheet({super.key, required this.item});

  final LostItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final matches = ref.watch(lostItemMatchesProvider(item.id));
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();

    return ForumSheetScaffold(
      children: [
        ForumSheetHeader(
          icon: Icons.auto_awesome,
          iconColors: toneColors(scheme, BadgeTone.primary),
          title: 'Correspondances possibles',
          subtitle: item.title,
          onClose: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: Text(
                item.isLost
                    ? 'Objets trouvés qui ressemblent à cette annonce.'
                    : 'Objets perdus qui ressemblent à cette annonce.',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            if (matches.valueOrNull?.ai ?? false) ...[
              const SizedBox(width: AppSpacing.sm),
              const _AiChip(),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ...matches.when(
          loading: () => const [_LoadingState()],
          error: (e, _) => [
            _MessageState(
              icon: Icons.cloud_off_outlined,
              title: 'Impossible de charger les correspondances',
              message: failureMessage(e),
              onRetry: () => ref.invalidate(lostItemMatchesProvider(item.id)),
            ),
          ],
          data: (result) => result.items.isEmpty
              ? const [
                  _MessageState(
                    icon: Icons.travel_explore,
                    title: 'Aucune correspondance pour le moment',
                    message: 'Nous comparons les nouvelles annonces à la vôtre : revenez plus tard.',
                  ),
                ]
              : [
                  for (final match in result.items) ...[
                    _MatchTile(
                      match: match,
                      now: now,
                      onTap: () => Navigator.of(context).pop(match.item),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
        ),
      ],
    );
  }
}

/// "IA" pill: the AI ranked these matches.
class _AiChip extends StatelessWidget {
  const _AiChip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, fg) = toneColors(theme.colorScheme, BadgeTone.primary);
    return Tooltip(
      message: "Classées par l'IA",
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.xl)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 14, color: fg),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'IA',
              style: theme.textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// One match: kind · zone · date, title, location, score bar and reason.
class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.match, required this.now, required this.onTap});

  final LostItemMatch match;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final item = match.item;
    final accent = lostItemAccent(scheme, item.action);
    final caption = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        borderRadius: AppRadius.mdAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(lostItemCategoryIcon(item.category), size: 16, color: accent),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      '${lostItemStatusLabel(item)} · ${formatLostItemTime(item.reportedAt, now: now)}'
                          .toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: caption,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${match.score} %',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(lostItemPlaceIcon(item.place), size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      item.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: match.score.clamp(0, 100) / 100,
                  minHeight: 6,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
              if (match.reason.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text.rich(
                  TextSpan(
                    children: [
                      if (match.ai)
                        TextSpan(
                          text: 'IA : ',
                          style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
                        ),
                      TextSpan(text: match.reason),
                    ],
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  "Voir l'annonce ›",
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          const SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Recherche de correspondances…',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Empty or error state, with a retry button for errors.
class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: scheme.surfaceContainerHigh,
            child: Icon(icon, size: 28, color: scheme.primary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.md),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Réessayer'),
            ),
          ],
        ],
      ),
    );
  }
}
