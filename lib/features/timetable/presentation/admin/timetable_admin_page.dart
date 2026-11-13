import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_snack.dart';
import '../../../../shared/widgets/detail_top_bar.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/class_session.dart';
import '../../domain/entities/timetable_slot.dart';
import '../../domain/timetable_slot_rules.dart';
import '../providers/timetable_admin_providers.dart';
import '../widgets/meet_link.dart';
import 'slot_form_page.dart';

/// Administration › Timetable: the weekly classes of the class group, by
/// day. Admins add, edit and remove classes; students and teachers are
/// notified of every change.
class TimetableAdminPage extends ConsumerWidget {
  const TimetableAdminPage({super.key});

  Future<void> _openForm(BuildContext context, WidgetRef ref, [TimetableSlot? slot]) async {
    final saved = await Navigator.of(context).push<TimetableSlot>(
      MaterialPageRoute(builder: (_) => SlotFormPage(slot: slot)),
    );
    if (saved == null || !context.mounted) return;
    ref.invalidate(adminTimetableSlotsProvider);
    showAppSnack(
      context,
      slot == null
          ? 'Class added. Students and teachers are notified.'
          : 'Changes saved. Students and teachers are notified.',
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, TimetableSlot slot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this class?'),
        content: Text(
          '${slot.course}, ${weekdayName(slot.weekday)} ${slot.start}–${slot.end}, is removed '
          'from every week. Students and teachers are notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final result = await ref.read(timetableAdminRepositoryProvider).deleteSlot(slot.id);
    if (!context.mounted) return;
    result.when(
      success: (_) {
        ref.invalidate(adminTimetableSlotsProvider);
        showAppSnack(context, 'Class removed. Students and teachers are notified.');
      },
      failure: (f) => showAppSnack(context, f.message),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(adminTimetableSlotsProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add a class'),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, 0),
              child: DetailTopBar(backLabel: 'Profile', fallbackPath: RoutePaths.profile),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page, AppSpacing.lg, AppSpacing.page, AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Timetable', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'The same classes every week. Students and teachers are notified '
                    'of every change.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                skipLoadingOnRefresh: true,
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(
                  message: failureMessage(e),
                  onRetry: () => ref.invalidate(adminTimetableSlotsProvider),
                ),
                data: (slots) => RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(adminTimetableSlotsProvider);
                    try {
                      await ref.read(adminTimetableSlotsProvider.future);
                    } catch (_) {
                      // Shown by the error view.
                    }
                  },
                  child: slots.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 120),
                            EmptyView(
                              message: 'No classes yet. Add the first one.',
                              icon: Icons.event_note_outlined,
                            ),
                          ],
                        )
                      : _WeekList(
                          slots: slots,
                          onEdit: (slot) => _openForm(context, ref, slot),
                          onDelete: (slot) => _delete(context, ref, slot),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The classes grouped by weekday (days without classes are left out).
class _WeekList extends StatelessWidget {
  const _WeekList({required this.slots, required this.onEdit, required this.onDelete});

  final List<TimetableSlot> slots;
  final ValueChanged<TimetableSlot> onEdit;
  final ValueChanged<TimetableSlot> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = [...slots]..sort(compareSlots);
    final children = <Widget>[];
    for (var day = 1; day <= 7; day++) {
      final ofDay = sorted.where((s) => s.weekday == day).toList();
      if (ofDay.isEmpty) continue;
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.lg, 0, AppSpacing.sm),
          child: Text(
            '${weekdayName(day)} · ${ofDay.length} ${ofDay.length == 1 ? 'class' : 'classes'}',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      );
      for (final slot in ofDay) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _SlotTile(
              slot: slot,
              onTap: () => onEdit(slot),
              onDelete: () => onDelete(slot),
            ),
          ),
        );
      }
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Room for the "Add a class" button.
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 96),
      children: children,
    );
  }
}

String _kindLabel(TimetableSlot s) => switch (s.kind) {
      SessionKind.lecture => 'Lecture',
      SessionKind.lab => 'Lab',
      SessionKind.workshop => 'Workshop',
      SessionKind.exam => 'Exam',
    };

class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.slot, required this.onTap, required this.onDelete});

  final TimetableSlot slot;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final place = slot.isOnline
        ? (slot.room.isEmpty ? 'Online' : 'Online · ${slot.room}')
        : slot.room;
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgAll,
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, 0, AppSpacing.md),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                child: Column(
                  children: [
                    Text(
                      slot.start,
                      style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      slot.end,
                      style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.course,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_kindLabel(slot)} · $place · ${slot.teacher}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    if (slot.isOnline) ...[
                      const SizedBox(height: AppSpacing.xs),
                      const OnlineChip(),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove ${slot.course}',
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, color: scheme.error),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
