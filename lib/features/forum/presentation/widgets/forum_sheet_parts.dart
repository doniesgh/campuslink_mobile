import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';

// Building blocks of the forum's publishing sheets, in the style of the
// Lost & Found request sheet (lost_item_request_sheet.dart).

/// Scrollable sheet body that stays above the keyboard.
class ForumSheetScaffold extends StatelessWidget {
  const ForumSheetScaffold({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page, 0, AppSpacing.page, AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      );
}

/// Icon, title, subtitle and close button.
class ForumSheetHeader extends StatelessWidget {
  const ForumSheetHeader({
    super.key,
    required this.icon,
    required this.iconColors,
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  final IconData icon;

  /// Background and foreground of the icon circle.
  final (Color, Color) iconColors;
  final String title;
  final String subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: iconColors.$1,
          child: Icon(icon, size: 20, color: iconColors.$2),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text(title, style: theme.textTheme.titleMedium)),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          tooltip: 'Fermer',
          onPressed: onClose,
          style: IconButton.styleFrom(
            backgroundColor: scheme.surfaceContainer,
            foregroundColor: scheme.onSurfaceVariant,
            minimumSize: const Size(32, 32),
            fixedSize: const Size(32, 32),
            padding: EdgeInsets.zero,
          ),
          icon: const Icon(Icons.close, size: 18),
        ),
      ],
    );
  }
}

/// Label above a field or a group of chips (same style as AppTextField's).
class ForumFieldLabel extends StatelessWidget {
  const ForumFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Small tinted note with an icon.
class ForumSheetNote extends StatelessWidget {
  const ForumSheetNote({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Error under a field, or the API's message above the submit button.
class ForumSheetError extends StatelessWidget {
  const ForumSheetError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
      ),
    );
  }
}
