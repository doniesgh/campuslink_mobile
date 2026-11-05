import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_search_field.dart';
import '../../../../shared/widgets/app_snack.dart';
import '../../../../shared/widgets/campus_header.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../carpooling/presentation/providers/carpool_providers.dart';
import '../../../carpooling/presentation/widgets/carpooling_section.dart';
import '../widgets/lost_found_section.dart';

enum ForumSection {
  carpooling('Covoiturage', Icons.directions_car_outlined),
  lostFound('Lost & Found', Icons.search),
  ideas('Ideas', Icons.lightbulb_outline),
  experiences('Experiences', Icons.auto_stories_outlined);

  const ForumSection(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Section shown by the Forum tab. Other screens set it before opening the
/// tab (e.g. Home's "Objets Perdus" shortcut opens Lost & Found).
final forumSectionProvider = StateProvider<ForumSection>((ref) => ForumSection.carpooling);

/// Forum hub: search, section chips and the content of the selected section.
class ForumPage extends ConsumerStatefulWidget {
  const ForumPage({super.key});

  @override
  ConsumerState<ForumPage> createState() => _ForumPageState();
}

class _ForumPageState extends ConsumerState<ForumPage> {
  String _query = '';

  /// Bumped to rebuild (and so empty) the search field.
  int _searchFieldGeneration = 0;

  void _comingSoon(String what) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('$what - coming soon')));

  void _clearSearch() => setState(() {
        _query = '';
        _searchFieldGeneration++;
      });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ridesCount = ref.watch(ridesProvider).valueOrNull?.length;
    final section = ref.watch(forumSectionProvider);

    return Scaffold(
      floatingActionButton: switch (section) {
        ForumSection.carpooling => FloatingActionButton.extended(
            onPressed: () => _comingSoon('Proposer un trajet'),
            backgroundColor: scheme.secondary,
            foregroundColor: scheme.onSecondary,
            icon: const Icon(Icons.directions_car),
            label: const Text('Proposer un trajet +'),
          ),
        ForumSection.lostFound => FloatingActionButton.extended(
            // TODO: open the "lost / found notice" form once the API exists.
            onPressed: () => showAppSnack(context, 'Publishing a notice is coming soon.'),
            backgroundColor: scheme.secondary,
            foregroundColor: scheme.onSecondary,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Publier une annonce'),
          ),
        _ => null,
      },
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const CampusHeader(section: 'Forum'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: AppSearchField(
                key: ValueKey(_searchFieldGeneration),
                hint: section == ForumSection.lostFound
                    ? 'Rechercher par objet, salle ou bloc...'
                    : 'Search rides, lost items, or campus...',
                onChanged: (v) => setState(() => _query = v),
                onFilterTap: () => _comingSoon('Filters'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                itemCount: ForumSection.values.length,
                separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (_, i) {
                  final s = ForumSection.values[i];
                  return _SectionChip(
                    section: s,
                    selected: s == section,
                    count: s == ForumSection.carpooling ? ridesCount : null,
                    // Placeholder "new activity" dot until the API provides it.
                    hasUpdates: s == ForumSection.lostFound,
                    onTap: () => ref.read(forumSectionProvider.notifier).state = s,
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: switch (section) {
                ForumSection.carpooling => CarpoolingSection(query: _query),
                ForumSection.lostFound =>
                  LostFoundSection(query: _query, onClearSearch: _clearSearch),
                _ => EmptyView(message: '${section.label} is coming soon.', icon: section.icon),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionChip extends StatelessWidget {
  const _SectionChip({
    required this.section,
    required this.selected,
    required this.onTap,
    this.count,
    this.hasUpdates = false,
  });

  final ForumSection section;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  final bool hasUpdates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = selected ? scheme.onPrimary : scheme.primary;

    return Material(
      color: selected ? scheme.primary : scheme.surfaceContainerLowest,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md + 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(section.icon, size: 16, color: fg),
              const SizedBox(width: AppSpacing.xs + 2),
              Text(section.label, style: theme.textTheme.labelLarge?.copyWith(color: fg)),
              if (count != null) ...[
                const SizedBox(width: AppSpacing.xs + 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm - 1),
                  decoration: BoxDecoration(
                    color: scheme.secondary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSecondary),
                  ),
                ),
              ],
              if (hasUpdates) ...[
                const SizedBox(width: AppSpacing.xs + 2),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: scheme.secondary, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
