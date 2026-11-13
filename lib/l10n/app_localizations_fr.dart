// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get commonErrorTooManyRequests =>
      'Trop de tentatives. Réessaie dans quelques minutes.';

  @override
  String get accountLanguageTitle => 'Langue';

  @override
  String get accountLanguageSubtitle => 'Appli, e-mails et notifications';
}
