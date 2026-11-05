import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';

/// "Digital Student Pass" shortcut under the timeline.
class StudentPassCard extends StatelessWidget {
  const StudentPassCard({super.key, required this.onOpen, this.examRoom});

  final VoidCallback onOpen;

  /// Room of the next exam of the day, if any (the pass is shown there).
  final String? examRoom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final room = examRoom;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.9),
        borderRadius: AppRadius.lgAll,
        boxShadow: AppShadows.card(scheme),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: AppRadius.lgAll,
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: scheme.primary, borderRadius: AppRadius.mdAll),
                  child: Icon(Icons.badge_outlined, size: 20, color: scheme.onPrimary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Digital Student Pass',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        room == null
                            ? 'Tap to show your barcode at the campus gate'
                            : 'Tap to show barcode at $room',
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Tooltip(
                  message: 'Open student pass',
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: scheme.surfaceContainer, shape: BoxShape.circle),
                    child: Icon(Icons.qr_code_scanner, size: 18, color: scheme.primary),
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
