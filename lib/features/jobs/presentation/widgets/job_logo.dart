import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';

/// Company logo placeholder (initials on the primary color).
class JobLogo extends StatelessWidget {
  const JobLogo({super.key, required this.initials, this.size = 56});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: AppRadius.mdAll,
      ),
      child: Text(
        initials,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
