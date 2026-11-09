import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/router/route_names.dart';
import '../../auth/domain/entities/user.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../data/push/firebase_push_messaging.dart';
import '../data/repositories/push_device_repository_impl.dart';
import '../domain/entities/push_message.dart';
import '../domain/push_messaging.dart';
import '../domain/repositories/push_device_repository.dart';
import 'notification_routes.dart';
import 'providers/notification_providers.dart';

/// The phone's push service, or null when push is off (no Firebase config,
/// demo mode, desktop). Set by bootstrap.dart.
final pushMessagingProvider = Provider<PushMessaging?>((_) => null);

final pushDeviceRepositoryProvider = Provider<PushDeviceRepository>(
  (ref) => PushDeviceRepositoryImpl(ref.watch(dioProvider)),
);

/// Runs for the whole life of the app (watched by CampusPulseApp), or null
/// when push is off.
final pushControllerProvider = Provider<PushController?>((ref) {
  final messaging = ref.watch(pushMessagingProvider);
  if (messaging == null) return null;
  final controller = PushController(
    ref,
    messaging,
    ref.watch(pushDeviceRepositoryProvider),
    platform: currentPushPlatform,
  );
  ref.onDispose(controller.dispose);
  controller.start();
  return controller;
});

/// Push notifications on this phone:
/// - registers it with the API while a verified user is signed in (after
///   asking for the permission), and again when Firebase renews the token;
/// - on sign-out, the token goes with the logout request (see
///   [pushTokenProvider]) and is then deleted, so nothing reaches the phone;
/// - a push received while the app is open refreshes the notifications and
///   shows a snackbar; a tapped push opens its screen and marks it as read.
class PushController {
  PushController(this._ref, this._messaging, this._devices, {required this.platform});

  final Ref _ref;
  final PushMessaging _messaging;
  final PushDeviceRepository _devices;
  final PushPlatform platform;

  final _subscriptions = <StreamSubscription<Object?>>[];

  /// The user this phone is registered for.
  String? _userId;
  var _checkedInitialMessage = false;

  void start() {
    _subscriptions
      ..add(_messaging.onTokenRefresh.listen(_onTokenRefresh))
      ..add(_messaging.onForegroundMessage.listen(_onForegroundMessage))
      ..add(_messaging.onMessageOpened.listen(open));
    _ref.listen<AsyncValue<User?>>(
      authControllerProvider,
      (_, auth) => unawaited(_onAuth(auth)),
      fireImmediately: true,
    );
  }

  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
  }

  Future<void> _onAuth(AsyncValue<User?> auth) async {
    if (auth.isLoading) return;
    final user = auth.valueOrNull;
    if (user == null || !user.isEmailVerified) {
      if (_userId != null) await _signedOut();
      return;
    }
    if (user.id == _userId) return;
    _userId = user.id;
    await _openInitialMessage();
    await _register(user.id);
  }

  /// The app was started by tapping a push: open it once someone is signed in.
  Future<void> _openInitialMessage() async {
    if (_checkedInitialMessage) return;
    _checkedInitialMessage = true;
    try {
      final message = await _messaging.getInitialMessage();
      if (message != null) open(message);
    } catch (e) {
      debugPrint('[push] Could not read the push that opened the app: $e');
    }
  }

  Future<void> _register(String userId) async {
    try {
      if (!await _messaging.requestPermission()) return;
      final token = await _messaging.getToken();
      // Signed out (or someone else signed in) while we were waiting.
      if (token == null || _userId != userId) return;
      await _save(token);
    } catch (e) {
      debugPrint('[push] Could not register this phone: $e');
    }
  }

  void _onTokenRefresh(String token) {
    if (_userId != null) unawaited(_save(token));
  }

  Future<void> _save(String token) async {
    (await _devices.register(token, platform)).when(
      success: (_) => _ref.read(pushTokenProvider.notifier).state = token,
      failure: (f) => debugPrint('[push] The API did not register this phone: ${f.message}'),
    );
  }

  Future<void> _signedOut() async {
    _userId = null;
    // AuthController.logout has already sent it to the API.
    _ref.read(pushTokenProvider.notifier).state = null;
    try {
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('[push] Could not delete the push token: $e');
    }
  }

  void _onForegroundMessage(PushMessage message) {
    // A notification of the feed (a class reminder has no id and isn't one).
    if (message.notificationId != null) _ref.invalidate(notificationsControllerProvider);
    final messenger = _ref.read(scaffoldMessengerKeyProvider).currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message.title.isEmpty ? message.body : message.title),
          action: SnackBarAction(label: 'View', onPressed: () => open(message)),
          // With an action, a snackbar stays until tapped by default.
          persist: false,
          duration: const Duration(seconds: 6),
        ),
      );
  }

  /// Opens the screen of a tapped push (the notifications list when it has
  /// no link) and marks it as read.
  void open(PushMessage message) {
    final router = _ref.read(routerProvider);
    final link = message.link;
    final route = link == null ? null : notificationRoute(link);
    if (route != null) {
      router.go(route);
    } else if (router.routeInformationProvider.value.uri.path != RoutePaths.notifications) {
      unawaited(router.push(RoutePaths.notifications));
    }
    final id = message.notificationId;
    if (id != null) unawaited(_markAsRead(id));
  }

  Future<void> _markAsRead(String id) async {
    // The list may not have the new notification yet: reload it first.
    _ref.invalidate(notificationsControllerProvider);
    try {
      await _ref.read(notificationsControllerProvider.future);
      await _ref.read(notificationsControllerProvider.notifier).markAsRead(id);
    } catch (_) {
      // The notifications screen shows the error.
    }
  }
}
