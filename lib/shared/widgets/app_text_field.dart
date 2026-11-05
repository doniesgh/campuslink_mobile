import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Labelled text field with optional password visibility toggle.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.isPassword = false,
    this.keyboardType,
    this.validator,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
    this.labelTrailing,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final bool isPassword;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;

  /// Shown at the end of the label row (e.g. a "Forgot?" link).
  final Widget? labelTrailing;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscure = widget.isPassword;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (widget.labelTrailing != null) widget.labelTrailing!,
          ],
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscure,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onSubmitted,
          autofillHints: widget.autofillHints,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon),
            suffixIcon: widget.isPassword
                ? IconButton(
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
