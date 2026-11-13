import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_controller.dart';

class _Tab {
  const _Tab(this.branch, this.label, this.icon, this.selectedIcon);

  /// Index of the tab's branch in app_router.dart.
  final int branch;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _timetableBranch = 1;

/// Bottom tabs. Branch indexes MUST match the branches in app_router.dart.
/// To add a tab (e.g. Notifications): add an entry here + one branch in the router.
const _tabs = [
  _Tab(0, 'Home', Icons.home_outlined, Icons.home),
  _Tab(_timetableBranch, 'Timetable', Icons.calendar_month_outlined, Icons.calendar_month),
  _Tab(2, 'Forum', Icons.forum_outlined, Icons.forum),
  _Tab(3, 'Jobs', Icons.work_outline, Icons.work),
  _Tab(4, 'Profile', Icons.person_outline, Icons.person),
];

/// Persistent bottom navigation around the main app tabs. Admins, alumni and companies
/// have no timetable, so they don't get its tab.
class ShellScaffold extends ConsumerWidget {
  const ShellScaffold({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasClasses = ref.watch(
      authControllerProvider.select((auth) => auth.valueOrNull?.hasClasses ?? true),
    );
    final tabs = [
      for (final t in _tabs)
        if (hasClasses || t.branch != _timetableBranch) t,
    ];
    final selected = tabs.indexWhere((t) => t.branch == shell.currentIndex);

    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected < 0 ? 0 : selected,
        onDestinationSelected: (i) {
          final branch = tabs[i].branch;
          shell.goBranch(branch, initialLocation: branch == shell.currentIndex);
        },
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.selectedIcon),
              label: t.label,
            ),
        ],
      ),
    );
  }
}
