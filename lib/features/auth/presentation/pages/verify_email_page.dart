import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_snack.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../providers/auth_controller.dart';
import '../widgets/auth_scaffold.dart';

/// Email verification code entry. Not in the Stitch file: built on the login layout.
class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final failure =
        await ref.read(authControllerProvider.notifier).verifyEmail(_code.text.trim());
    // On success the router opens the app and this page is disposed.
    if (!mounted) return;
    setState(() => _loading = false);
    if (failure != null) showAppSnack(context, failure.message);
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authControllerProvider).valueOrNull?.email;
    return AuthScaffold(
      heroHeight: 220,
      title: 'Check your inbox',
      subtitle: email == null
          ? 'Enter the 6-digit code we emailed you'
          : 'Enter the 6-digit code sent to $email',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _code,
              label: 'Verification code',
              hint: '123456',
              prefixIcon: Icons.pin_outlined,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.oneTimeCode],
              onSubmitted: (_) => _submit(),
              validator: Validators.code,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Verify email',
              trailingIcon: Icons.check,
              variant: AppButtonVariant.accent,
              isLoading: _loading,
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpacing.xl),
            AuthFooter(
              prompt: 'Wrong account?',
              action: 'Sign out',
              onTap: () => ref.read(authControllerProvider.notifier).logout(),
            ),
          ],
        ),
      ),
    );
  }
}
