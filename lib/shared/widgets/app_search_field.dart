import 'package:flutter/material.dart';

/// Search input with an optional filter button.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.onFilterTap,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onFilterTap;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: onFilterTap == null
            ? null
            : IconButton(icon: const Icon(Icons.tune), onPressed: onFilterTap),
      ),
    );
  }
}
