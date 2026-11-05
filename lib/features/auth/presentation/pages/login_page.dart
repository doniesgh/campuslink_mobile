import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/env.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_snack.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../providers/auth_controller.dart';
import '../widgets/auth_scaffold.dart';

/// Stitch "01. Onboarding & Login".
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _remember = true;
  bool _loading = false;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final failure = await ref
        .read(authControllerProvider.notifier)
        .login(_identifier.text.trim(), _password.text);
    // On success the router redirects away and this page is disposed.
    if (!mounted) return;
    setState(() => _loading = false);
    if (failure != null) showAppSnack(context, failure.message);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Sign in to your campus',
      subtitle: 'Access courses, covoiturage, grades & digital ID',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppButton(
                label: 'Continue with University SSO',
                icon: Icons.verified_user,
                onPressed: () => showAppSnack(context, 'University SSO is not available yet.'),
              ),
              const AuthDivider(label: 'or continue with student credentials'),
              AppTextField(
                controller: _identifier,
                label: 'Identifiant ENT',
                hint: 'Ex: 211JMT0000',
                prefixIcon: Icons.badge_outlined,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                validator: (v) => Validators.notEmpty(v, 'Enter your ENT ID or email'),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _password,
                label: 'Mot de passe',
                hint: 'Entrez votre mot de passe',
                prefixIcon: Icons.lock_outline,
                isPassword: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
                validator: (v) => Validators.notEmpty(v, 'Enter your password'),
                labelTrailing: AuthLink(
                  label: 'Forgot?',
                  onTap: () => context.push(RoutePaths.forgotPassword),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _RememberCheckbox(
                      value: _remember,
                      onChanged: (v) => setState(() => _remember = v),
                    ),
                  ),
                  const _GatewayStatus(),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Sign In',
                trailingIcon: Icons.arrow_forward,
                variant: AppButtonVariant.accent,
                isLoading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.xl),
              AuthFooter(
                prompt: 'New student?',
                action: 'Register →',
                onTap: () => context.push(RoutePaths.register),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Remember terminal session".
// TODO: wire to session persistence once the backend supports short sessions.
class _RememberCheckbox extends StatelessWidget {
  const _RememberCheckbox({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 24,
            child: Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: theme.colorScheme.secondary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              'Remember terminal session',
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small status pill: tells whether the app talks to the real API or mock data.
class _GatewayStatus extends StatelessWidget {
  const _GatewayStatus();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            Env.useMock ? 'DEMO MODE' : 'GATEWAY ONLINE',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: scheme.brightness == Brightness.dark
                  ? AppColors.success
                  : AppColors.successText,
            ),
          ),
        ],
      ),
    );
  }
}
