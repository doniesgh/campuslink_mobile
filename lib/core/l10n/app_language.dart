import 'dart:ui';

/// The languages of the app. [name] is the code the API uses (`user.locale`,
/// `Accept-Language`) and that the preferences store.
enum AppLanguage {
  fr('Français'),
  en('English');

  const AppLanguage(this.nativeName);

  /// The language's name in itself ("Français", "English"): how a language
  /// picker lists it, whatever the current language.
  final String nativeName;

  /// "fr" or "en".
  String get code => name;

  Locale get locale => Locale(name);

  /// The language with [code] ("fr", "EN", "en-GB"...), or null.
  static AppLanguage? fromCode(Object? code) {
    if (code is! String) return null;
    final language = code.trim().toLowerCase().split(RegExp('[-_]')).first;
    for (final value in values) {
      if (value.name == language) return value;
    }
    return null;
  }

  /// French: the language when nothing else decides.
  static const fallback = AppLanguage.fr;
}

/// The language to show: the user's [saved] choice, else the first of the
/// device's [deviceLocales] (in its order of preference) that the app speaks,
/// else French.
AppLanguage resolveAppLanguage(String? saved, List<Locale> deviceLocales) {
  final chosen = AppLanguage.fromCode(saved);
  if (chosen != null) return chosen;
  for (final locale in deviceLocales) {
    final language = AppLanguage.fromCode(locale.languageCode);
    if (language != null) return language;
  }
  return AppLanguage.fallback;
}
