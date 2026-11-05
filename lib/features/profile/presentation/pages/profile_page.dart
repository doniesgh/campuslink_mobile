import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/theme_provider.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/placeholder_page.dart';
import '../../../auth/presentation/providers/auth_controller.dart';

/// Placeholder with a theme switch and logout to validate the foundation.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final user = ref.watch(authControllerProvider).valueOrNull;
    return PlaceholderPage(
      title: 'Profile',
      children: [
        if (user != null) Text(user.email),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.light, label: Text('Light')),
            ButtonSegment(value: ThemeMode.system, label: Text('System')),
            ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
          ],
          selected: {mode},
          onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
        ),
        AppButton(
          label: 'Log out',
          variant: AppButtonVariant.outlined,
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
        ),
      ],
    );
  }
}
