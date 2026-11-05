import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class _Tab {
  const _Tab(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Bottom tabs. Order MUST match the branches in app_router.dart.
/// To add a tab (e.g. Notifications): add an entry here + one branch in the router.
const _tabs = [
  _Tab('Home', Icons.home_outlined, Icons.home),
  _Tab('Timetable', Icons.calendar_month_outlined, Icons.calendar_month),
  _Tab('Forum', Icons.forum_outlined, Icons.forum),
  _Tab('Jobs', Icons.work_outline, Icons.work),
  _Tab('Profile', Icons.person_outline, Icons.person),
];

/// Persistent bottom navigation around the main app tabs.
class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          for (final t in _tabs)
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
