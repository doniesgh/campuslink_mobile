// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonErrorTooManyRequests =>
      'Too many attempts. Try again in a few minutes.';

  @override
  String get accountLanguageTitle => 'Language';

  @override
  String get accountLanguageSubtitle => 'App, emails and notifications';
}
