import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../forum/presentation/pages/forum_page.dart';

class _QuickAction {
  const _QuickAction(this.label, this.icon, this.tone, this.path, [this.forumSection]);

  final String label;
  final IconData icon;
  final BadgeTone tone;
  final String path;

  /// Forum section to open, for shortcuts into the Forum tab.
  final ForumSection? forumSection;
}

const _carpool = _QuickAction('Covoiturage', Icons.directions_car, BadgeTone.accent,
    RoutePaths.forum, ForumSection.carpooling);
const _lostFound = _QuickAction('Objets Perdus', Icons.manage_search, BadgeTone.primary,
    RoutePaths.forum, ForumSection.lostFound);
const _planning =
    _QuickAction('Planning', Icons.calendar_month, BadgeTone.accent, RoutePaths.timetable);
const _accounts = _QuickAction(
    'Comptes', Icons.manage_accounts_outlined, BadgeTone.accent, RoutePaths.adminUsers);
const _offers = _QuickAction('Offres', Icons.work_outline, BadgeTone.accent, RoutePaths.jobs);
const _ideas = _QuickAction('Idées', Icons.lightbulb_outline, BadgeTone.primary,
    RoutePaths.forum, ForumSection.ideas);

/// Row of 4 shortcut tiles under the "Up next" card. Without a timetable,
/// "Planning" becomes the accounts (admins) or the job offers (alumni).
class QuickActions extends StatelessWidget {
  const QuickActions({super.key, this.role = UserRole.student});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _carpool,
      _lostFound,
      if (role.hasClasses)
        _planning
      else if (role == UserRole.admin)
        _accounts
      else
        _offers,
      _ideas,
    ];
    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.md),
          Expanded(child: _QuickActionTile(action: actions[i])),
        ],
      ],
    );
  }
}

class _QuickActionTile extends ConsumerWidget {
  const _QuickActionTile({required this.action});

  final _QuickAction action;

  void _open(BuildContext context, WidgetRef ref) {
    final section = action.forumSection;
    if (section != null) ref.read(forumSectionProvider.notifier).state = section;
    context.go(action.path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final (bg, fg) = toneColors(theme.colorScheme, action.tone);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
      onTap: () => _open(context, ref),
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
