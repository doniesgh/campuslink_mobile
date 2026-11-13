import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

export '../../l10n/app_localizations.dart';

/// The app's texts in the current language: `context.l10n.accountLanguageTitle`.
///
/// The same as `AppLocalizations.of(context)`. Every MaterialApp of the app
/// has the delegates (app.dart); widget tests use
/// `test/helpers/localized_app.dart`.
extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
