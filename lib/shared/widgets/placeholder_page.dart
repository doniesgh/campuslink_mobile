import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Temporary page used until a feature screen is implemented.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title, this.children = const []});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.md,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const Text('Placeholder - to be implemented'),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
