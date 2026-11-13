import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/providers/clock_provider.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_snack.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/lost_item.dart';
import '../providers/forum_providers.dart';
import 'lost_found_visuals.dart';
import 'lost_item_card.dart';
import 'lost_item_request_sheet.dart';

const _page = EdgeInsets.symmetric(horizontal: AppSpacing.page);

/// Content of the "Lost & Found" tab of the forum
/// (Stitch "07. Lost & Found Campus Items").
class LostFoundSection extends ConsumerStatefulWidget {
  const LostFoundSection(
      {super.key, required this.query, required this.onClearSearch});

  /// Text typed in the forum search field.
  final String query;

  /// Empties the forum search field ("Réinitialiser la recherche").
  final VoidCallback onClearSearch;

  @override
  ConsumerState<LostFoundSection> createState() => _LostFoundSectionState();
}

class _LostFoundSectionState extends ConsumerState<LostFoundSection> {
  /// null = "Tous".
  LostItemKind? _kind;

  Future<void> _refresh() async {
    ref.invalidate(lostItemsProvider);
    try {
      await ref.read(lostItemsProvider.future);
    } catch (_) {
      // The error is shown in place of the list.
    }
  }

  void _reset() {
    setState(() => _kind = null);
    if (widget.query.isNotEmpty) widget.onClearSearch();
  }

  Future<void> _openRequest(LostItem item) async {
    final sent = await showLostItemRequestSheet(context, item);
    if (sent && mounted)
      showAppSnack(context, 'Signalement transmis au staff de sécurité !');
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(lostItemsProvider);
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();

    return items.when(
      skipLoadingOnReload: true,
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(
        message: failureMessage(e),
        onRetry: () => ref.invalidate(lostItemsProvider),
      ),
      data: (all) {
        final matching = filterLostItems(all, query: widget.query);
        final visible = filterLostItems(matching, kind: _kind);
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.only(
                top: AppSpacing.xs, bottom: 96), // room for the FAB
            children: [
              const Padding(padding: _page, child: _CampusContextHeader()),
              const SizedBox(height: AppSpacing.md),
              _FilterPills(
                selected: _kind,
                counts: countLostItems(matching),
                onSelected: (kind) => setState(() => _kind = kind),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (visible.isEmpty)
                Padding(
                  padding: _page,
                  child: _NoMatchView(
                    onReset: widget.query.trim().isEmpty && _kind == null
                        ? null
                        : _reset,
                  ),
                )
              else
                for (final item in visible)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      0,
                      AppSpacing.page,
                      AppSpacing.md,
                    ),
                    child: GestureDetector(
                      onTap: () =>
                          context.push(RoutePaths.lostItemDetail(item.id)),
                      child: LostItemCard(
                        item: item,
                        now: now,
                        onAction: () => _openRequest(item),
                      ),
                    ),
                  ),
            
            ],
          ),
        );
      },
    );
  }
}

/// Campus pill, desk opening hours, title and subtitle.
class _CampusContextHeader extends StatelessWidget {
  const _CampusContextHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label =
        theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Text('Objets Perdus & Trouvés', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 2),
        Text(
          'Retrouvez vos effets ou déclarez un objet égaré dans les blocs',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// "Tous 18" / "● Objets Perdus 7" / "● Objets Trouvés 11".
class _FilterPills extends StatelessWidget {
  const _FilterPills(
      {required this.selected, required this.counts, required this.onSelected});

  final LostItemKind? selected;
  final LostItemCounts counts;
  final ValueChanged<LostItemKind?> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: _page,
      child: Row(
        children: [
          _FilterPill(
            label: 'Tous',
            count: counts.all,
            selected: selected == null,
            selectedColors: (scheme.primary, scheme.onPrimary),
            onTap: () => onSelected(null),
          ),
          const SizedBox(width: AppSpacing.sm),
          _FilterPill(
            label: 'Objets Perdus',
            count: counts.lost,
            dotColor: scheme.secondary,
            selected: selected == LostItemKind.lost,
            selectedColors: (scheme.secondary, scheme.onSecondary),
            onTap: () => onSelected(LostItemKind.lost),
          ),
          const SizedBox(width: AppSpacing.sm),
          _FilterPill(
            label: 'Objets Trouvés',
            count: counts.found,
            dotColor: scheme.primary,
            selected: selected == LostItemKind.found,
            selectedColors: (scheme.primary, scheme.onPrimary),
            onTap: () => onSelected(LostItemKind.found),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.selectedColors,
    required this.onTap,
    this.dotColor,
  });

  final String label;
  final int count;
  final bool selected;

  /// Background and foreground when selected.
  final (Color, Color) selectedColors;
  final VoidCallback onTap;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (bg, fg) = selected
        ? selectedColors
        : (scheme.surfaceContainer, scheme.onSurfaceVariant);
    final bubble =
        selected ? fg.withValues(alpha: 0.22) : scheme.surfaceContainerHighest;
    final style = theme.textTheme.labelMedium
        ?.copyWith(color: fg, fontWeight: FontWeight.w700);

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: bg,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dotColor != null && !selected) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: dotColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(label, style: style),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                      color: bubble, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    '$count',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: fg, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty search / filter result.
class _NoMatchView extends StatelessWidget {
  const _NoMatchView({required this.onReset});

  /// Null when there is no search or filter to reset.
  final VoidCallback? onReset;

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
            child: Icon(Icons.travel_explore, size: 32, color: scheme.primary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Aucun objet correspondant',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Essayez un autre mot-clé ou publiez un avis de recherche pour alerter '
            'la communauté ESPRIT.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (onReset != null) ...[
            const SizedBox(height: AppSpacing.lg),
            TextButton(
              onPressed: onReset,
              style: TextButton.styleFrom(
                backgroundColor: scheme.surfaceContainer,
                foregroundColor: scheme.primary,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              ),
              child: const Text('Réinitialiser la recherche'),
            ),
          ],
        ],
      ),
    );
  }
}