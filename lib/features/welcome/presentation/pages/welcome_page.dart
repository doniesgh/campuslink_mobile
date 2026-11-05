import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/placeholder_page.dart';

/// Placeholder: the real Welcome page is the next deliverable.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});
  @override
  Widget build(BuildContext context) => PlaceholderPage(
        title: 'CampusPulse',
        children: [
          AppButton(
            label: 'Get Started',
            variant: AppButtonVariant.accent,
            onPressed: () => context.go(RoutePaths.login),
          ),
          AppButton(
            label: 'Login',
            variant: AppButtonVariant.outlined,
            onPressed: () => context.go(RoutePaths.login),
          ),
        ],
      );
}
