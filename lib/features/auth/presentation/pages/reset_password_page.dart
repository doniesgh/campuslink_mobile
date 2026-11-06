import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_snack.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../providers/auth_controller.dart';
import '../widgets/auth_scaffold.dart';

/// Second step of "Forgot password": the emailed 6-digit code + a new password.
/// Route: RoutePaths.resetPasswordFor(email).
class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key, required this.email});

  /// Where the code was sent. Empty if the page was opened without it.
  final String email;

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final failure = await ref
        .read(authControllerProvider.notifier)
        .resetPassword(widget.email, _code.text.trim(), _password.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (failure != null) {
      showAppSnack(context, failure.message);
      return;
    }
    showAppSnack(context, 'Password updated. Sign in with your new password.');
    context.go(RoutePaths.login);
  }

  Future<void> _resend() async {
    final failure = await ref.read(authControllerProvider.notifier).forgotPassword(widget.email);
    if (!mounted) return;
    showAppSnack(context, failure?.message ?? 'A new code is on its way to ${widget.email}.');
  }

  @override
  Widget build(BuildContext context) {
    final hasEmail = widget.email.isNotEmpty;
    return AuthScaffold(
      heroHeight: 220,
      title: 'Choose a new password',
      subtitle: hasEmail
          ? 'Enter the 6-digit code sent to ${widget.email}'
          : 'Enter the 6-digit code we emailed you',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _code,
                label: 'Reset code',
                hint: '123456',
                prefixIcon: Icons.pin_outlined,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.oneTimeCode],
                validator: Validators.code,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _password,
                label: 'New password',
                hint: 'At least 8 characters',
                prefixIcon: Icons.lock_outline,
                isPassword: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => _submit(),
                validator: Validators.newPassword,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Update password',
                trailingIcon: Icons.check,
                variant: AppButtonVariant.accent,
                isLoading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.xl),
              hasEmail
                  ? AuthFooter(prompt: "Didn't get it?", action: 'Send a new code', onTap: _resend)
                  : AuthFooter(
                      prompt: 'No code yet?',
                      action: 'Enter my email',
                      onTap: () => context.go(RoutePaths.forgotPassword),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
