import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/router/route_names.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/placeholder_page.dart';
import '../providers/auth_controller.dart';

/// Temporary placeholders (real screens come in the next steps).
/// Each one exercises the full flow: UI -> controller -> repository -> (mock) API.

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PlaceholderPage(
        title: 'Login',
        children: [
          _ActionButton(
            label: 'Sign in (mock)',
            action: () => ref
                .read(authControllerProvider.notifier)
                .login('student@campus.test', 'password'),
          ),
          TextButton(
            onPressed: () => context.push(RoutePaths.register),
            child: const Text('Register'),
          ),
          TextButton(
            onPressed: () => context.push(RoutePaths.forgotPassword),
            child: const Text('Forgot password'),
          ),
        ],
      );
}

class RegisterPage extends ConsumerWidget {
  const RegisterPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PlaceholderPage(
        title: 'Register',
        children: [
          _ActionButton(
            label: 'Register (mock)',
            action: () => ref
                .read(authControllerProvider.notifier)
                .register('New Student', 'new@campus.test', 'password'),
          ),
        ],
      );
}

class ForgotPasswordPage extends ConsumerWidget {
  const ForgotPasswordPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PlaceholderPage(
        title: 'Forgot password',
        children: [
          _ActionButton(
            label: 'Send reset link (mock)',
            action: () => ref
                .read(authControllerProvider.notifier)
                .forgotPassword('student@campus.test'),
          ),
        ],
      );
}

class VerifyEmailPage extends ConsumerWidget {
  const VerifyEmailPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PlaceholderPage(
        title: 'Verify email',
        children: [
          _ActionButton(
            label: 'Verify (mock)',
            action: () =>
                ref.read(authControllerProvider.notifier).verifyEmail('123456'),
          ),
          TextButton(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            child: const Text('Cancel'),
          ),
        ],
      );
}

/// Button with loading state that shows the [Failure] message on error.
class _ActionButton extends StatefulWidget {
  const _ActionButton({required this.label, required this.action});
  final String label;
  final Future<Failure?> Function() action;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _loading = false;

  Future<void> _run() async {
    setState(() => _loading = true);
    final failure = await widget.action();
    if (!mounted) return;
    setState(() => _loading = false);
    if (failure != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  @override
  Widget build(BuildContext context) =>
      AppButton(label: widget.label, onPressed: _run, isLoading: _loading);
}
