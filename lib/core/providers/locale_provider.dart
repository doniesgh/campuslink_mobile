import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_controller.dart';
import '../l10n/app_language.dart';
import 'core_providers.dart';

/// The device's preferred languages, most preferred first (overridden in tests).
final deviceLocalesProvider = Provider<List<Locale>>(
  (_) => PlatformDispatcher.instance.locales,
);

/// The language the app shows (see [resolveAppLanguage]): the user's choice,
/// saved on the phone, else the device's language if it is French or
/// English, else French.
///
/// - `MaterialApp.router` takes its `locale` from it (app.dart).
/// - Every API request sends it as `Accept-Language` (dio_client.dart).
/// - The signed-in account's `locale` follows it, so the server writes the
///   emails and notifications in it (see `AuthController.syncLanguage`).
///
/// Read it with `ref.watch(localeProvider)`; change it with
/// `ref.read(localeProvider.notifier).set(AppLanguage.en)`. Widgets read the
/// texts with `AppLocalizations.of(context)` (or `context.l10n`).
final localeProvider =
    NotifierProvider<LocaleNotifier, AppLanguage>(LocaleNotifier.new);

class LocaleNotifier extends Notifier<AppLanguage> {
  @override
  AppLanguage build() => resolveAppLanguage(
        ref.read(localPrefsProvider).locale,
        ref.read(deviceLocalesProvider),
      );

  /// Shows the app in [language] and remembers the choice. When someone is
  /// signed in, their account's language follows (in the background; a
  /// failure is ignored: the next sign-in tries again).
  void set(AppLanguage language) {
    state = language;
    unawaited(ref.read(localPrefsProvider).saveLocale(language.code));
    unawaited(ref.read(authControllerProvider.notifier).syncLanguage(language));
  }
}
