import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/config/env.dart';
import '../../domain/entities/push_message.dart';
import '../../domain/push_messaging.dart';

/// Starts Firebase for push notifications. Returns null (push off) in demo
/// mode, on platforms without FCM (desktop, web), or when the Firebase
/// config is missing: `android/app/google-services.json` (Android) or
/// `ios/Runner/GoogleService-Info.plist` (iOS). Never throws.
Future<PushMessaging?> startPushMessaging() async {
  if (Env.useMock || kIsWeb) return null;
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    return null;
  }
  try {
    await Firebase.initializeApp();
    return FirebasePushMessaging(FirebaseMessaging.instance);
  } catch (e) {
    debugPrint('[push] Off: no Firebase configuration for this app ($e).');
    return null;
  }
}

/// This phone's platform, as the API names it.
PushPlatform get currentPushPlatform =>
    defaultTargetPlatform == TargetPlatform.iOS ? PushPlatform.ios : PushPlatform.android;

/// [PushMessaging] backed by Firebase Cloud Messaging.
///
/// Uses FCM registration tokens: the API sends with firebase-admin, whose
/// messages target tokens. firebase_messaging 17 deprecates them in favour of
/// Installation IDs (`register()`/`onRegistered`) for a newer send API; switch
/// both sides together when the backend can send to those.
// ignore_for_file: deprecated_member_use
class FirebasePushMessaging implements PushMessaging {
  FirebasePushMessaging(this._fcm);

  final FirebaseMessaging _fcm;

  @override
  Future<bool> requestPermission() async {
    final settings = await _fcm.requestPermission();
    return switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized || AuthorizationStatus.provisional => true,
      AuthorizationStatus.denied ||
      AuthorizationStatus.deniedPermanently ||
      AuthorizationStatus.notDetermined =>
        false,
    };
  }

  @override
  Future<String?> getToken() => _fcm.getToken();

  @override
  Stream<String> get onTokenRefresh => _fcm.onTokenRefresh;

  @override
  Stream<PushMessage> get onForegroundMessage => FirebaseMessaging.onMessage.map(_toPush);

  @override
  Stream<PushMessage> get onMessageOpened => FirebaseMessaging.onMessageOpenedApp.map(_toPush);

  @override
  Future<PushMessage?> getInitialMessage() async {
    final message = await _fcm.getInitialMessage();
    return message == null ? null : _toPush(message);
  }

  @override
  Future<void> deleteToken() => _fcm.deleteToken();

  static PushMessage _toPush(RemoteMessage message) => PushMessage.fromData(
        title: message.notification?.title,
        body: message.notification?.body,
        data: message.data,
      );
}
