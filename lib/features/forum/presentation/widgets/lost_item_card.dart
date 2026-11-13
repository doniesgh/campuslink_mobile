import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/lost_item.dart';
import '../utils/lost_found_formatters.dart';
import 'lost_found_visuals.dart';

/// Item card of the Lost & Found board (Stitch "07. Lost & Found Campus Items").
///
/// The claim action is for other students' active notices. The reporter
/// (or an admin) gets a "Gérer l'annonce" menu: edit, resolve, delete.
class LostItemCard extends StatelessWidget {
  const LostItemCard({
    super.key,
    required this.item,
    required this.now,
    required this.onAction,
    this.onMatches,
    this.onEdit,
    this.onToggleResolved,
    this.onDelete,
  });

  final LostItem item;
  final DateTime now;

  /// Claim / "J'ai trouvé cet objet !" / serial-number check.
  final VoidCallback onAction;

  /// "Correspondances possibles" (active notices only). Null: no button.
  final VoidCallback? onMatches;

  /// The manage menu's entries, shown when [LostItem.canManage]. Null: no entry.
  final VoidCallback? onEdit;
  final VoidCallback? onToggleResolved;
  final VoidCallback? onDelete;

  /// Not on a resolved notice, nor on the student's own one.
  bool get _showsAction => !item.isResolved && !item.isMine;

  bool get _showsMenu =>
      item.canManage && (onEdit != null || onToggleResolved != null || onDelete != null);

  @override
  Widget build(BuildContext context) {
    final accent = lostItemAccent(Theme.of(context).colorScheme, item.action);
    final strip = _DetailStrip.of(item);
    final onMatches = this.onMatches;

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: _showsAction ? onAction : null,
      child: ClipRRect(
        borderRadius: AppRadius.lgAll,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Thumbnail(item: item, accent: accent),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: _Summary(item: item, now: now, accent: accent)),
                      if (_showsMenu)
                        _ManageMenu(
                          isResolved: item.isResolved,
                          onEdit: onEdit,
                          onToggleResolved: onToggleResolved,
                          onDelete: onDelete,
                        ),
                    ],
                  ),
                  if (strip != null) ...[const SizedBox(height: AppSpacing.md), strip],
                  if (item.isResolved) ...[
                    const SizedBox(height: AppSpacing.md),
                    const _ResolvedBanner(),
                  ],
                  if (_showsAction) ...[
                    const SizedBox(height: AppSpacing.md),
                    _ActionButton(action: item.action, onPressed: onAction),
                  ],
                  if (!item.isResolved && onMatches != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _MatchesButton(prominent: !_showsAction, onPressed: onMatches),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: SizedBox(width: 4, child: ColoredBox(color: accent)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Illustrative placeholder in place of the item photo, with the
/// "Urgent" and photo-count overlays of the mockup.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.item, required this.accent});

  final LostItem item;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final overlayText = theme.textTheme.labelSmall?.copyWith(
      fontSize: 9,
      fontWeight: FontWeight.w700,
      height: 1.2,
    );
    final urgentBg = scheme.brightness == Brightness.dark ? scheme.secondary : AppColors.accentText;

    // Fixed-size box: keep the overlay labels inside it at large font sizes.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Color.alphaBlend(accent.withValues(alpha: 0.10), scheme.surfaceContainer),
          borderRadius: AppRadius.mdAll,
        ),
        child: Stack(
          children: [
            Center(child: Icon(lostItemCategoryIcon(item.category), size: 36, color: accent)),
            if (item.isUrgent)
              Positioned(
                top: AppSpacing.xs,
                left: AppSpacing.xs,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: urgentBg, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    'URGENT',
                    style: overlayText?.copyWith(color: scheme.onSecondary, letterSpacing: 0.6),
                  ),
                ),
              ),
            if (item.photoCount > 0)
              Positioned(
                bottom: AppSpacing.xs,
                right: AppSpacing.xs,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.photo_camera_outlined, size: 10, color: scheme.surface),
                      const SizedBox(width: 2),
                      Text('${item.photoCount}', style: overlayText?.copyWith(color: scheme.surface)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Status pill + time, title, location and reporter.
class _Summary extends StatelessWidget {
  const _Summary({required this.item, required this.now, required this.accent});

  final LostItem item;
  final DateTime now;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (IconData reporterIcon, Color reporterColor) = item.isLost
        ? (Icons.contact_support_outlined, scheme.secondary)
        : item.reporterIsStaff
            ? (Icons.badge_outlined, scheme.primary)
            : (Icons.person_outline, lostFoundSuccessColor(scheme));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            _StatusPill(item: item),
            Text(
              formatLostItemTime(item.reportedAt, now: now),
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 2),
        _InfoLine(
          icon: lostItemPlaceIcon(item.place),
          iconColor: accent,
          text: TextSpan(text: item.location),
        ),
        const SizedBox(height: 2),
        _InfoLine(
          icon: reporterIcon,
          iconColor: reporterColor,
          text: TextSpan(
            text: '${lostItemReporterPrefix(item)} ',
            children: [
              TextSpan(
                text: item.reporterName,
                style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "● Trouvé · Bloc C" (green) / "● Perdu · Parking" (coral).
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.item});

  final LostItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (Color bg, Color fg, Color dot) = item.isLost
        ? (toneColors(scheme, BadgeTone.accent).$1, lostFoundAccentText(scheme), scheme.secondary)
        : (scheme.surfaceContainer, lostFoundSuccessColor(scheme), AppColors.success);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              lostItemStatusLabel(item),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.iconColor, required this.text});

  final IconData icon;
  final Color iconColor;
  final TextSpan text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text.rich(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// Extra info under the summary: drop-off note (or pickup desk) + reference,
/// hidden serial number (found items) or reward + distinctive detail (lost
/// items).
class _DetailStrip extends StatelessWidget {
  const _DetailStrip._(this.item);

  final LostItem item;

  /// Null when the item has nothing to show in the strip.
  static _DetailStrip? of(LostItem item) {
    final hasContent = item.isLost
        ? item.reward != null || item.distinctiveDetail != null
        : item.isSerialHidden ||
            item.dropOffNote != null ||
            item.pickupDesk != null ||
            item.reference != null;
    return hasContent ? _DetailStrip._(item) : null;
  }

  @override
  Widget build(BuildContext context) => item.isLost ? _lostStrip(context) : _foundStrip(context);

  Widget _foundStrip(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700);
    final success = lostFoundSuccessColor(scheme);
    // Notices published by students give the pickup desk only.
    final desk = item.pickupDesk;
    final note = item.dropOffNote ?? (desk == null ? null : 'Retrait : $desk');
    final reference = item.reference;

    final (IconData, Color, String, Color)? lead = item.isSerialHidden
        ? (
            Icons.qr_code_scanner,
            scheme.primary,
            'Numéro de série masqué pour identification',
            scheme.onSurfaceVariant,
          )
        : note == null
            ? null
            : (Icons.verified_user_outlined, success, note, success);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: AppRadius.mdAll),
      // Wrap: the reference goes to its own line when both don't fit.
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          if (lead != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(lead.$1, size: 16, color: lead.$2),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    lead.$3,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: label?.copyWith(color: lead.$4),
                  ),
                ),
              ],
            ),
          if (reference != null)
            Text(
              'Réf #$reference',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: label?.copyWith(color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }

  Widget _lostStrip(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reward = item.reward;
    final detail = item.distinctiveDetail;

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        if (reward != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: AppSpacing.xs),
            decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: AppRadius.smAll),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_cafe_outlined, size: 16, color: scheme.secondary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    reward,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: lostFoundAccentText(scheme),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (detail != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 14, color: scheme.outline),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

enum _ManageAction { edit, toggleResolved, delete }

/// "Gérer l'annonce" (⋮): Modifier, Marquer comme résolue / Réactiver, Supprimer.
class _ManageMenu extends StatelessWidget {
  const _ManageMenu({
    required this.isResolved,
    required this.onEdit,
    required this.onToggleResolved,
    required this.onDelete,
  });

  final bool isResolved;
  final VoidCallback? onEdit;
  final VoidCallback? onToggleResolved;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onEdit = this.onEdit;
    final onToggleResolved = this.onToggleResolved;
    final onDelete = this.onDelete;

    PopupMenuItem<_ManageAction> entry(
      _ManageAction value,
      IconData icon,
      String label, {
      Color? color,
    }) =>
        PopupMenuItem(
          value: value,
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: AppSpacing.md),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color),
                ),
              ),
            ],
          ),
        );

    return SizedBox(
      width: 36,
      height: 36,
      child: PopupMenuButton<_ManageAction>(
        tooltip: "Gérer l'annonce",
        padding: EdgeInsets.zero,
        iconSize: 20,
        icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant),
        onSelected: (action) => switch (action) {
          _ManageAction.edit => onEdit?.call(),
          _ManageAction.toggleResolved => onToggleResolved?.call(),
          _ManageAction.delete => onDelete?.call(),
        },
        itemBuilder: (_) => [
          if (onEdit != null) entry(_ManageAction.edit, Icons.edit_outlined, 'Modifier'),
          if (onToggleResolved != null)
            isResolved
                ? entry(_ManageAction.toggleResolved, Icons.replay, "Réactiver l'annonce")
                : entry(
                    _ManageAction.toggleResolved,
                    Icons.check_circle_outline,
                    'Marquer comme résolue',
                  ),
          if (onDelete != null)
            entry(_ManageAction.delete, Icons.delete_outline, 'Supprimer', color: scheme.error),
        ],
      ),
    );
  }
}

/// In place of the action on a resolved notice.
class _ResolvedBanner extends StatelessWidget {
  const _ResolvedBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, fg) = toneColors(theme.colorScheme, BadgeTone.success);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.mdAll),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 18, color: fg),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Résolu · objet rendu à son propriétaire',
              style: theme.textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Correspondances possibles": filled on the student's own notice (it is
/// then the main action), outlined under the claim action otherwise.
class _MatchesButton extends StatelessWidget {
  const _MatchesButton({required this.prominent, required this.onPressed});

  final bool prominent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(40)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: AppRadius.mdAll)),
    );
    const icon = Icon(Icons.auto_awesome, size: 18);
    const label = Text('Correspondances possibles', maxLines: 1, overflow: TextOverflow.ellipsis);
    return prominent
        ? FilledButton.tonalIcon(onPressed: onPressed, style: style, icon: icon, label: label)
        : OutlinedButton.icon(onPressed: onPressed, style: style, icon: icon, label: label);
  }
}

/// Full-width action, styled per action as in the mockup.
class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action, required this.onPressed});

  final LostItemAction action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color bg, Color fg, IconData icon, String label) = switch (action) {
      LostItemAction.claim => (
          scheme.primary,
          scheme.onPrimary,
          Icons.pan_tool_outlined,
          "C'est à moi / Réclamer",
        ),
      LostItemAction.reportFound => (
          toneColors(scheme, BadgeTone.accent).$1,
          lostFoundAccentText(scheme),
          Icons.saved_search,
          "J'ai trouvé cet objet !",
        ),
      LostItemAction.verifySerial => (
          scheme.surfaceContainer,
          scheme.primary,
          Icons.barcode_reader,
          'Vérifier le numéro de série',
        ),
    };

    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        minimumSize: const Size.fromHeight(44),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
