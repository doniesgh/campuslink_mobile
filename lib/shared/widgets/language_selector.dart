import 'package:flutter/material.dart';

import '../../core/l10n/app_language.dart';

/// Compact FR / EN segmented pill (the twin of the theme selector). Each
/// language is named in itself ("Français", "English") for screen readers
/// and in its tooltip, so it can be found whatever the current language.
///
/// Wire it to the app's language:
/// `LanguageSelector(language: ref.watch(localeProvider),
///     onChanged: ref.read(localeProvider.notifier).set)`.
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key, required this.language, required this.onChanged});

  final AppLanguage language;
  final ValueChanged<AppLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final value in AppLanguage.values)
            _LanguageButton(
              language: value,
              selected: value == language,
              onTap: () => onChanged(value),
            ),
        ],
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({required this.language, required this.selected, required this.onTap});

  final AppLanguage language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Tooltip(
      message: language.nativeName,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        selected: selected,
        inMutuallyExclusiveGroup: true,
        label: language.nativeName,
        excludeSemantics: true,
        child: Material(
          color: selected ? scheme.primary : Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox.square(
              dimension: 34,
              child: Center(
                child: Text(
                  language.code.toUpperCase(),
                  // Fixed size: the pill keeps its shape at large text scales.
                  textScaler: TextScaler.noScaling,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
