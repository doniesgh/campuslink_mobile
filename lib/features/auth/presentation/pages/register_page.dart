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

/// Account creation. Not in the Stitch file: built on the login layout.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final failure = await ref
        .read(authControllerProvider.notifier)
        .register(_name.text.trim(), _email.text.trim(), _password.text);
    // On success the router sends the new user to email verification.
    if (!mounted) return;
    setState(() => _loading = false);
    if (failure != null) showAppSnack(context, failure.message);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      heroHeight: 220,
      title: 'Create your account',
      subtitle: 'Join CampusPulse with your student email',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _name,
                label: 'Full name',
                hint: 'Ex: Sarra Kefi',
                prefixIcon: Icons.person_outline,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: (v) => Validators.notEmpty(v, 'Enter your name'),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _email,
                label: 'Student email',
                hint: 'prenom.nom@esprit.tn',
                prefixIcon: Icons.alternate_email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: Validators.email,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _password,
                label: 'Password',
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
                label: 'Create account',
                trailingIcon: Icons.arrow_forward,
                variant: AppButtonVariant.accent,
                isLoading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.xl),
              AuthFooter(
                prompt: 'Already registered?',
                action: 'Sign in',
                onTap: () => context.canPop() ? context.pop() : context.go(RoutePaths.login),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
