import 'package:flutter/material.dart';

/// Shows [message] in a snackbar, replacing the one currently visible.
void showAppSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
