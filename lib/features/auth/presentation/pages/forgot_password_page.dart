import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure_text.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_snack.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../providers/auth_controller.dart';
import '../widgets/auth_scaffold.dart';

/// Password reset request. Not in the Stitch file: built on the login layout.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _backToLogin() => context.canPop() ? context.pop() : context.go(RoutePaths.login);

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final email = _email.text.trim();
    final failure = await ref.read(authControllerProvider.notifier).forgotPassword(email);
    if (!mounted) return;
    setState(() => _loading = false);
    if (failure != null) {
      showAppSnack(context, failureText(context, failure));
      return;
    }
    // Step 2: enter the emailed code and a new password. Back goes to login.
    context.pushReplacement(RoutePaths.resetPasswordFor(email));
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      heroHeight: 220,
      title: 'Reset your password',
      subtitle: "We'll email you a 6-digit code to choose a new one",
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _email,
              label: 'Student email',
              hint: 'prenom.nom@esprit.tn',
              prefixIcon: Icons.alternate_email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              onSubmitted: (_) => _submit(),
              validator: Validators.email,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Send the code',
              trailingIcon: Icons.send_rounded,
              variant: AppButtonVariant.accent,
              isLoading: _loading,
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpacing.xl),
            AuthFooter(prompt: 'Remembered it?', action: 'Back to sign in', onTap: _backToLogin),
          ],
        ),
      ),
    );
  }
}
