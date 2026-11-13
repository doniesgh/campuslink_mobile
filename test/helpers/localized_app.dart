import 'package:campuspulse/core/l10n/app_language.dart';
import 'package:campuspulse/core/l10n/l10n.dart';
import 'package:campuspulse/core/providers/locale_provider.dart';
import 'package:campuspulse/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Helpers for widget tests of screens that use the app's texts
/// (`AppLocalizations.of(context)` / `context.l10n`).
///
/// - A plain `MaterialApp`: `await tester.pumpWidget(localizedApp(const MyPage()));`
/// - A `MaterialApp.router` of your own: pass it `localizationsDelegates:
///   testLocalizationsDelegates, supportedLocales: testSupportedLocales,
///   locale: AppLanguage.en.locale`.
/// - Anything that watches `localeProvider` (e.g. the Profile tab): add
///   `localeOverride()` to the `ProviderScope` overrides (no SharedPreferences).
///
/// Tests run in English unless they ask for French: most of them check
/// English texts.

/// The app's localization delegates (its texts, and Material's in FR/EN).
const testLocalizationsDelegates = AppLocalizations.localizationsDelegates;

/// French and English.
const testSupportedLocales = AppLocalizations.supportedLocales;

/// The app's texts in [language], outside of a widget (e.g. to compare with
/// what a screen shows): `l10nFor(AppLanguage.fr).accountLanguageTitle`.
AppLocalizations l10nFor(AppLanguage language) => lookupAppLocalizations(language.locale);

/// [home] in a `MaterialApp` with the app's texts in [language], a plain
/// theme (the app theme pulls Google Fonts from the network) and [textScale].
Widget localizedApp(
  Widget home, {
  AppLanguage language = AppLanguage.en,
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) =>
    MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: brightness),
      ),
      locale: language.locale,
      supportedLocales: testSupportedLocales,
      localizationsDelegates: testLocalizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: home,
    );

/// The language setting without SharedPreferences: it starts at [initial]
/// and remembers the languages set, in [changes]. It doesn't update the
/// signed-in account (test that with the real `LocaleNotifier`).
class FakeLocaleNotifier extends LocaleNotifier {
  FakeLocaleNotifier([this.initial = AppLanguage.en]);

  final AppLanguage initial;
  final changes = <AppLanguage>[];

  @override
  AppLanguage build() => initial;

  @override
  void set(AppLanguage language) {
    changes.add(language);
    state = language;
  }
}

/// Overrides `localeProvider` with a [FakeLocaleNotifier] (or [notifier]).
Override localeOverride([FakeLocaleNotifier? notifier]) =>
    localeProvider.overrideWith(() => notifier ?? FakeLocaleNotifier());
