import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_snack.dart';

/// Shows the sign-in details of an account the admin just created or whose
/// password they changed, with a Copy button: the password is shown only now.
Future<void> showSignInDetailsDialog(
  BuildContext context, {
  required String name,
  required String email,
  required String password,
  String? studentId,
  String title = 'Sign-in details',
}) {
  final lines = [
    'Email: $email',
    if (studentId != null && studentId.isNotEmpty) 'ENT ID: $studentId',
    'Password: $password',
  ];
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Give these to $name. The password won't be shown again."),
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: AppRadius.mdAll,
              ),
              child: SelectableText(
                lines.join('\n'),
                style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: '$name\n${lines.join('\n')}'));
              if (ctx.mounted) showAppSnack(ctx, 'Sign-in details copied.');
            },
          ),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Done')),
        ],
      );
    },
  );
}
