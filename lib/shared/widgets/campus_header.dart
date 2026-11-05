import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/theme_provider.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/auth/presentation/providers/auth_controller.dart';
import 'user_avatar.dart';

/// Top header of the main tabs: brand + section name, theme toggle, avatar.
class CampusHeader extends ConsumerWidget {
  const CampusHeader({super.key, required this.section});

  final String section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final name = ref.watch(authControllerProvider).valueOrNull?.displayName ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.md,
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CampusPulse',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                section,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const Spacer(),
          const _ThemeTogglePill(),
          const SizedBox(width: AppSpacing.md),
          UserAvatar(name: name),
        ],
      ),
    );
  }
}

class _ThemeTogglePill extends ConsumerWidget {
  const _ThemeTogglePill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final active = scheme.primary;
    final muted = scheme.onSurfaceVariant.withValues(alpha: 0.5);
    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.5),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => ref
            .read(themeModeProvider.notifier)
            .set(dark ? ThemeMode.light : ThemeMode.dark),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm - 1,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.light_mode_outlined, size: 16, color: dark ? muted : active),
              Text(' / ', style: TextStyle(color: muted)),
              Icon(Icons.dark_mode_outlined, size: 16, color: dark ? active : muted),
            ],
          ),
        ),
      ),
    );
  }
}
