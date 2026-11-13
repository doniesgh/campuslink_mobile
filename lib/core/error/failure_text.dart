import 'package:flutter/widgets.dart';

import '../l10n/l10n.dart';
import 'failures.dart';

/// The message to show for [error], in the app's language when its `code`
/// is one the app translates; otherwise the server's own message (see
/// [failureMessage]).
///
/// Translate a new code by adding a `commonError…` key to both ARB files and
/// a case below.
String failureText(BuildContext context, Object error) {
  if (error is! Failure) return failureMessage(error);
  final l10n = context.l10n;
  return switch (error.code) {
    'TOO_MANY_REQUESTS' => l10n.commonErrorTooManyRequests,
    _ => error.message,
  };
}
