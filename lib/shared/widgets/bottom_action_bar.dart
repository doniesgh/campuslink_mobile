import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Sticky bottom bar: summary on the left, main action on the right.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.leading, required this.action});

  final Widget leading;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(flex: 2, child: leading),
              const SizedBox(width: AppSpacing.lg),
              Expanded(flex: 3, child: action),
            ],
          ),
        ),
      ),
    );
  }
}
