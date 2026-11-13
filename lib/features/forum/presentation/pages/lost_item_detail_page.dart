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
import '../../domain/entities/lost_item.dart';
import '../providers/forum_providers.dart';
import '../utils/lost_found_formatters.dart';
import '../widgets/lost_found_visuals.dart';
import '../widgets/lost_item_request_sheet.dart';

/// Full detail view for a Lost & Found item.
/// • Owner ([LostItem.isMine]): shows Delete + Edit action buttons.
/// • Other students: shows the claim / reportFound / verifySerial action.
class LostItemDetailPage extends ConsumerStatefulWidget {
  const LostItemDetailPage({super.key, required this.itemId});

  final String itemId;

  @override
  ConsumerState<LostItemDetailPage> createState() => _LostItemDetailPageState();
}

class _LostItemDetailPageState extends ConsumerState<LostItemDetailPage> {
  bool _deleting = false;

  Future<void> _openRequest(LostItem item) async {
    final sent = await showLostItemRequestSheet(context, item);
    if (sent && mounted) showAppSnack(context, 'Signalement transmis au staff de sécurité !');
  }

  Future<void> _confirmDelete(LostItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette annonce ?'),
        content: const Text(
          'Cette action est irréversible. Votre annonce sera définitivement supprimée.',
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
    final error = await deleteLostItem(ref, item.id);
    if (!mounted) return;
    setState(() => _deleting = false);

    if (error != null) {
      showAppSnack(context, error);
    } else {
      Navigator.of(context).pop();
      showAppSnack(context, 'Annonce supprimée.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(lostItemsProvider);
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: itemsAsync.when(
          skipLoadingOnReload: true,
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: failureMessage(e),
            onRetry: () => ref.invalidate(lostItemsProvider),
          ),
          data: (all) {
            final item = all.cast<LostItem?>().firstWhere(
                  (i) => i?.id == widget.itemId,
                  orElse: () => null,
                );
            if (item == null) {
              return const ErrorView(message: "Cet objet n'est plus disponible.");
            }
            return _LostItemDetailContent(
              item: item,
              now: now,
              deleting: _deleting,
              onDelete: item.isMine ? () => _confirmDelete(item) : null,
              onRequest: item.isMine ? null : () => _openRequest(item),
            );
          },
        ),
      ),
    );
  }
}

class _LostItemDetailContent extends StatelessWidget {
  const _LostItemDetailContent({
    required this.item,
    required this.now,
    required this.deleting,
    required this.onDelete,
    required this.onRequest,
  });

  final LostItem item;
  final DateTime now;
  final bool deleting;
  final VoidCallback? onDelete;
  final VoidCallback? onRequest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isOwner = item.isMine;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.md,
              AppSpacing.page,
              AppSpacing.lg + (isOwner || onRequest != null ? 0 : MediaQuery.paddingOf(context).bottom),
            ),
            children: [
              DetailTopBar(
                backLabel: 'Retour au Forum',
                fallbackPath: '/app/forum',
                trailing: [
                  Flexible(
                    child: AppBadge(
                      item.isLost ? 'Perdu' : 'Trouvé',
                      tone: item.isLost ? BadgeTone.accent : BadgeTone.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Title row with category icon
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: AppRadius.mdAll,
                    ),
                    child: Icon(
                      lostItemCategoryIcon(item.category),
                      size: 26,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 2),
                        Text(
                          '${lostItemStatusLabel(item)} · ${formatLostItemTime(item.reportedAt, now: now)}',
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Info rows
              _InfoSection(item: item),
              const SizedBox(height: AppSpacing.md),

              // Reporter
              _ReporterRow(item: item),
              if (item.isUrgent) ...[
                const SizedBox(height: AppSpacing.md),
                _UrgentBanner(),
              ],
              if (item.reward != null) ...[
                const SizedBox(height: AppSpacing.md),
                _DetailChip(
                  icon: Icons.card_giftcard_outlined,
                  label: 'Récompense',
                  value: item.reward!,
                ),
              ],
            ],
          ),
        ),

        // Bottom bar: owner sees Delete; others see Claim/Found action
        if (isOwner)
          BottomActionBar(
            leading: Text(
              'Votre annonce',
              style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            action: AppButton(
              label: 'Supprimer',
              icon: Icons.delete_outline,
              variant: AppButtonVariant.outlined,
              isLoading: deleting,
              onPressed: onDelete,
            ),
          )
        else if (onRequest != null)
          BottomActionBar(
            leading: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.reference ?? '',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                Text(
                  _actionLabel(item),
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            action: AppButton(
              label: _actionLabel(item),
              icon: Icons.send_outlined,
              onPressed: onRequest,
            ),
          ),
      ],
    );
  }

  String _actionLabel(LostItem item) => switch (item.action) {
        LostItemAction.claim => "C'est à moi",
        LostItemAction.reportFound => "J'ai trouvé cet objet !",
        LostItemAction.verifySerial => 'Vérifier le numéro de série',
      };
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.item});
  final LostItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        children: [
          _InfoRow(icon: Icons.location_on_outlined, label: 'Lieu', value: item.location),
          if (item.distinctiveDetail != null)
            _InfoRow(
              icon: Icons.search,
              label: 'Détail distinctif',
              value: item.distinctiveDetail!,
            ),
          if (item.dropOffNote != null)
            _InfoRow(icon: Icons.inbox_outlined, label: 'Déposé', value: item.dropOffNote!),
          if (item.pickupDesk != null)
            _InfoRow(
              icon: Icons.storefront_outlined,
              label: 'Récupération',
              value: item.pickupDesk!,
              last: true,
            )
          else
            _InfoRow(
              icon: Icons.category_outlined,
              label: 'Catégorie',
              value: lostItemCategoryLabel(item.category),
              last: true,
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            children: [
              Icon(icon, size: 18, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    Text(value, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!last)
          Divider(height: 1, indent: AppSpacing.md + 18 + AppSpacing.sm, color: scheme.outlineVariant),
      ],
    );
  }
}

class _ReporterRow extends StatelessWidget {
  const _ReporterRow({required this.item});
  final LostItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: scheme.surfaceContainerHigh,
          child: Icon(
            item.reporterIsStaff ? Icons.shield_outlined : Icons.person_outline,
            size: 18,
            color: scheme.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            '${lostItemReporterPrefix(item)} ${item.reporterName}${item.reporterIsStaff ? ' (staff)' : ''}',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _UrgentBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          Icon(Icons.priority_high, size: 16, color: scheme.onErrorContainer),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Urgent',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: scheme.onErrorContainer, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: AppRadius.lgAll,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.secondary),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
              Text(value, style: theme.textTheme.bodyMedium),
            ],
          ),
        ],
      ),
    );
  }
}
