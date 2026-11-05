import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_card.dart';

class _QuickAction {
  const _QuickAction(this.label, this.icon, this.tone, this.path);

  final String label;
  final IconData icon;
  final BadgeTone tone;
  final String path;
}

// TODO: open the matching forum section once ForumPage accepts one.
const _actions = [
  _QuickAction('Covoiturage', Icons.directions_car, BadgeTone.accent, RoutePaths.forum),
  _QuickAction('Objets Perdus', Icons.manage_search, BadgeTone.primary, RoutePaths.forum),
  _QuickAction('Planning', Icons.calendar_month, BadgeTone.accent, RoutePaths.timetable),
  _QuickAction('Idées', Icons.lightbulb_outline, BadgeTone.primary, RoutePaths.forum),
];

/// Row of 4 shortcut tiles under the "Up next" card.
class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _actions.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.md),
          Expanded(child: _QuickActionTile(action: _actions[i])),
        ],
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, fg) = toneColors(theme.colorScheme, action.tone);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
      onTap: () => context.go(action.path),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: bg, borderRadius: AppRadius.mdAll),
            child: Icon(action.icon, color: fg),
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(action.label, maxLines: 1, style: theme.textTheme.labelSmall),
          ),
        ],
      ),
    );
  }
}
