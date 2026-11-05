import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_button.dart';

/// Attendance toggle + "Join Course Discord & Forum" at the end of the page.
class CourseActions extends StatelessWidget {
  const CourseActions({
    super.key,
    required this.isPresent,
    required this.savingAttendance,
    required this.onToggleAttendance,
    required this.onJoinCommunity,
  });

  final bool isPresent;
  final bool savingAttendance;
  final VoidCallback onToggleAttendance;
  final VoidCallback onJoinCommunity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (_, accentFg) = toneColors(scheme, BadgeTone.accent);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: savingAttendance ? null : onToggleAttendance,
          style: FilledButton.styleFrom(
            backgroundColor: scheme.surfaceContainer,
            foregroundColor: scheme.onSurface,
            disabledBackgroundColor: scheme.surfaceContainer,
            disabledForegroundColor: scheme.onSurfaceVariant,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
          ),
          child: savingAttendance
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, size: 20, color: accentFg),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        isPresent ? 'Attendance Logged (Tap to Undo)' : 'Mark as Present Now',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 10),
        AppButton(
          label: 'Join Course Discord & Forum',
          icon: Icons.groups,
          onPressed: onJoinCommunity,
        ),
      ],
    );
  }
}
