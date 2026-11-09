import 'entities/push_message.dart';

/// The phone's push service (Firebase Cloud Messaging). An interface so the
/// app can run without Firebase (push off) and tests can fake it.
abstract interface class PushMessaging {
  /// Asks to show notifications (the Android 13+ / iOS prompt, once).
  /// True when allowed.
  Future<bool> requestPermission();

  /// This phone's push token, or null when it can't get one.
  Future<String?> getToken();

  /// A new token replaced the old one: register it again.
  Stream<String> get onTokenRefresh;

  /// Pushes received while the app is open. The system shows nothing for
  /// those: the app does.
  Stream<PushMessage> get onForegroundMessage;

  /// The user tapped a push while the app was in the background.
  Stream<PushMessage> get onMessageOpened;

  /// The push the user tapped to start the app, if any (asked once).
  Future<PushMessage?> getInitialMessage();

  /// Forgets this phone's token: pushes sent to it are no longer delivered.
  Future<void> deleteToken();
}
