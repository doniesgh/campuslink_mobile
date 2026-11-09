import 'dart:async';

import 'package:campuspulse/core/error/failures.dart';
import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/core/providers/clock_provider.dart';
import 'package:campuspulse/core/providers/core_providers.dart';
import 'package:campuspulse/core/providers/theme_provider.dart';
import 'package:campuspulse/core/router/app_router.dart';
import 'package:campuspulse/core/theme/app_colors.dart';
import 'package:campuspulse/features/auth/domain/entities/user.dart';
import 'package:campuspulse/features/auth/domain/repositories/auth_repository.dart';
import 'package:campuspulse/features/auth/presentation/providers/auth_controller.dart';
import 'package:campuspulse/features/forum/domain/entities/forum_post.dart';
import 'package:campuspulse/features/forum/domain/repositories/forum_repository.dart';
import 'package:campuspulse/features/forum/presentation/providers/forum_providers.dart';
import 'package:campuspulse/features/notifications/data/repositories/mock_notification_repository.dart';
import 'package:campuspulse/features/notifications/domain/entities/app_notification.dart';
import 'package:campuspulse/features/notifications/domain/entities/push_message.dart';
import 'package:campuspulse/features/notifications/domain/push_messaging.dart';
import 'package:campuspulse/features/notifications/domain/repositories/push_device_repository.dart';
import 'package:campuspulse/features/notifications/presentation/pages/notifications_page.dart';
import 'package:campuspulse/features/notifications/presentation/providers/notification_providers.dart';
import 'package:campuspulse/features/notifications/presentation/push_controller.dart';
import 'package:campuspulse/features/profile/data/repositories/mock_profile_repository.dart';
import 'package:campuspulse/features/profile/presentation/pages/profile_page.dart';
import 'package:campuspulse/features/profile/presentation/providers/profile_providers.dart';
import 'package:campuspulse/features/timetable/domain/entities/class_session.dart';
import 'package:campuspulse/features/timetable/domain/entities/timetable_week.dart';
import 'package:campuspulse/features/timetable/domain/repositories/timetable_repository.dart';
import 'package:campuspulse/features/timetable/presentation/pages/timetable_page.dart';
import 'package:campuspulse/features/timetable/presentation/providers/timetable_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _student = User(
  id: 'u1',
  email: 'student@campus.test',
  displayName: 'Sam Student',
  isEmailVerified: true,
);
const _other = User(
  id: 'u2',
  email: 'other@campus.test',
  displayName: 'Olivia Other',
  isEmailVerified: true,
);

/// Firebase stand-in: the test drives its streams.
class _FakePush implements PushMessaging {
  bool allowed = true;
  String? token = 'token-1';
  PushMessage? initialMessage;
  int deletedTokens = 0;
  final refresh = StreamController<String>.broadcast();
  final foreground = StreamController<PushMessage>.broadcast();
  final opened = StreamController<PushMessage>.broadcast();

  @override
  Future<bool> requestPermission() async => allowed;

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<String> get onTokenRefresh => refresh.stream;

  @override
  Stream<PushMessage> get onForegroundMessage => foreground.stream;

  @override
  Stream<PushMessage> get onMessageOpened => opened.stream;

  @override
  Future<PushMessage?> getInitialMessage() async {
    final message = initialMessage;
    initialMessage = null;
    return message;
  }

  @override
  Future<void> deleteToken() async => deletedTokens++;
}

class _FakeDevices implements PushDeviceRepository {
  final registered = <(String, PushPlatform)>[];
  bool offline = false;

  @override
  Future<Result<void>> register(String token, PushPlatform platform) async {
    if (offline) return const Err(NetworkFailure());
    registered.add((token, platform));
    return const Success(null);
  }
}

/// The real AuthController runs on this: sign-in, sign-out and what logout sends.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.signedIn);

  User? signedIn;
  User? nextLogin;
  final logoutPushTokens = <String?>[];

  @override
  Future<Result<User?>> restoreSession() async => Success(signedIn);

  @override
  Future<Result<User>> login({required String identifier, required String password}) async =>
      Success(signedIn = nextLogin!);

  @override
  Future<void> logout({String? pushToken}) async {
    logoutPushTokens.add(pushToken);
    signedIn = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Harness {
  _Harness({User? user = _student})
      : push = _FakePush(),
        devices = _FakeDevices(),
        auth = _FakeAuthRepository(user);

  final _FakePush push;
  final _FakeDevices devices;
  final _FakeAuthRepository auth;

  List<Override> get overrides => [
        authRepositoryProvider.overrideWithValue(auth),
        pushMessagingProvider.overrideWithValue(push),
        pushDeviceRepositoryProvider.overrideWithValue(devices),
      ];

  /// A container with push running, once the session is restored.
  Future<ProviderContainer> start() async {
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    container.read(pushControllerProvider);
    await container.read(authControllerProvider.future);
    await pumpEventQueue();
    return container;
  }
}

// ---- Widget harness: the app around the push controller ----

class _FakeThemeModeNotifier extends ThemeModeNotifier {
  @override
  ThemeMode build() => ThemeMode.light;

  @override
  void set(ThemeMode mode) => state = mode;
}

class _EmptyTimetable implements TimetableRepository {
  @override
  Future<Result<TimetableDay>> getDay(DateTime day) async =>
      Success(TimetableDay(date: day, sessions: const []));

  @override
  Future<Result<TimetableWeek>> getWeek(DateTime day) async => Success(TimetableWeek(
        start: day,
        days: [
          for (var i = 0; i < 7; i++)
            TimetableDay(date: day.add(Duration(days: i)), sessions: const []),
        ],
      ));
}

class _QuietForum implements ForumRepository {
  @override
  Future<Result<List<ForumPost>>> getHighlights() async => const Success([]);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// The demo notifications, counting the loads and the read marks.
class _CountingNotifications extends MockNotificationRepository {
  _CountingNotifications() : super(latency: Duration.zero);

  int loads = 0;
  final marked = <String>[];

  @override
  Future<Result<List<AppNotification>>> getNotifications() {
    loads++;
    return super.getNotifications();
  }

  @override
  Future<Result<void>> markAsRead(String id) {
    marked.add(id);
    return super.markAsRead(id);
  }
}

Future<(_Harness, _CountingNotifications)> _pumpApp(
  WidgetTester tester, {
  void Function(_Harness)? before,
}) async {
  tester.view.physicalSize = const Size(400, 800) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final harness = _Harness();
  before?.call(harness);
  final notifications = _CountingNotifications();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...harness.overrides,
        themeModeProvider.overrideWith(_FakeThemeModeNotifier.new),
        clockProvider.overrideWith((ref) => Stream.value(DateTime(2026, 11, 9, 9))),
        timetableRepositoryProvider.overrideWithValue(_EmptyTimetable()),
        forumRepositoryProvider.overrideWithValue(_QuietForum()),
        notificationRepositoryProvider.overrideWithValue(notifications),
        profileRepositoryProvider.overrideWithValue(
          MockProfileRepository(latency: Duration.zero, clock: () => DateTime(2026, 11, 9)),
        ),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          // As in CampusPulseApp.
          ref.watch(pushControllerProvider);
          return MaterialApp.router(
            theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary)),
            routerConfig: ref.watch(routerProvider),
            scaffoldMessengerKey: ref.watch(scaffoldMessengerKeyProvider),
          );
        },
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
  return (harness, notifications);
}

/// A class reminder as the API sends it: no notification id, opens the timetable.
const _classReminder = PushMessage(
  title: 'Algorithmes & Complexité',
  body: 'Lecture in 15 min · 08:30–10:00 · Amphi A',
  link: NotificationLink(NotificationDestination.timetable),
);

const _accountPush = PushMessage(
  title: 'Your account was updated',
  body: 'Your role is now: Teacher.',
  notificationId: 'room-change-gl',
  link: NotificationLink(NotificationDestination.profile),
);

void main() {
  group('PushMessage.fromData', () {
    test('reads the id and the link the API sends', () {
      final message = PushMessage.fromData(
        title: 'New account: Sarra',
        body: 'sarra@campus.test just signed up.',
        data: {
          'notificationId': 'n1',
          'category': 'account',
          'destination': 'adminUsers',
          'targetId': 'u42',
        },
      );

      expect(message.notificationId, 'n1');
      expect(message.link?.destination, NotificationDestination.adminUsers);
      expect(message.link?.id, 'u42');
    });

    test('no link without a known destination; empty strings are null', () {
      final plain = PushMessage.fromData(
        title: 'Push test',
        data: {'notificationId': 'n2', 'destination': '', 'targetId': ''},
      );
      final unknown = PushMessage.fromData(data: {'destination': 'moon'});

      expect(plain.link, isNull);
      expect(plain.body, '');
      expect(unknown.link, isNull);
      expect(unknown.notificationId, isNull);
    });
  });

  group('registration', () {
    test('a signed-in user gets the phone registered, and the token kept for logout', () async {
      final h = _Harness();
      final container = await h.start();

      expect(h.devices.registered, [('token-1', PushPlatform.android)]);
      expect(container.read(pushTokenProvider), 'token-1');
    });

    test('nothing is registered without the permission', () async {
      final h = _Harness()..push.allowed = false;
      final container = await h.start();

      expect(h.devices.registered, isEmpty);
      expect(container.read(pushTokenProvider), isNull);
    });

    test('nothing is registered while signed out or before the email is verified', () async {
      final signedOut = _Harness(user: null);
      await signedOut.start();
      final unverified = _Harness(
        user: const User(id: 'u3', email: 'new@campus.test', displayName: 'New'),
      );
      await unverified.start();

      expect(signedOut.devices.registered, isEmpty);
      expect(unverified.devices.registered, isEmpty);
    });

    test('the API being unreachable leaves no token to send at logout', () async {
      final h = _Harness()..devices.offline = true;
      final container = await h.start();

      expect(container.read(pushTokenProvider), isNull);
    });

    test('a renewed token is registered again', () async {
      final h = _Harness();
      final container = await h.start();

      h.push.refresh.add('token-2');
      await pumpEventQueue();

      expect(h.devices.registered.map((d) => d.$1), ['token-1', 'token-2']);
      expect(container.read(pushTokenProvider), 'token-2');
    });

    test('signing out sends the token with the logout, then deletes it', () async {
      final h = _Harness();
      final container = await h.start();

      await container.read(authControllerProvider.notifier).logout();
      await pumpEventQueue();

      expect(h.auth.logoutPushTokens, ['token-1']);
      expect(h.push.deletedTokens, 1);
      expect(container.read(pushTokenProvider), isNull);

      // A renewed token no longer registers anything.
      h.push.refresh.add('token-3');
      await pumpEventQueue();
      expect(h.devices.registered, hasLength(1));
    });

    test('the next user to sign in registers the phone for themselves', () async {
      final h = _Harness();
      final container = await h.start();
      await container.read(authControllerProvider.notifier).logout();
      await pumpEventQueue();

      h.push.token = 'token-4';
      h.auth.nextLogin = _other;
      await container.read(authControllerProvider.notifier).login('other@campus.test', 'pw');
      await pumpEventQueue();

      expect(h.devices.registered.map((d) => d.$1), ['token-1', 'token-4']);
      expect(container.read(pushTokenProvider), 'token-4');
    });
  });

  group('in the app', () {
    testWidgets('a push received while the app is open refreshes the list and shows it',
        (tester) async {
      final (h, notifications) = await _pumpApp(tester);
      final loadsBefore = notifications.loads;

      h.push.foreground.add(
        const PushMessage(title: 'Push test', body: 'It works.', notificationId: 'n-test'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Push test'), findsOneWidget);
      expect(notifications.loads, greaterThan(loadsBefore));

      await tester.tap(find.text('View'));
      // Not pumpAndSettle: the notifications page keeps an animation running.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(NotificationsPage), findsOneWidget);
    });

    testWidgets('the banner of a push goes away on its own', (tester) async {
      final (h, _) = await _pumpApp(tester);

      h.push.foreground.add(const PushMessage(title: 'Push test', body: 'It works.'));
      await tester.pumpAndSettle();
      expect(find.text('Push test'), findsOneWidget);

      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();
      expect(find.text('Push test'), findsNothing);
    });

    testWidgets('tapping a push opens its screen and marks it as read', (tester) async {
      final (h, notifications) = await _pumpApp(tester);

      h.push.opened.add(_accountPush);
      await tester.pumpAndSettle();

      expect(find.byType(ProfilePage), findsOneWidget);
      expect(notifications.marked, ['room-change-gl']);
    });

    testWidgets('a class reminder opens the timetable and marks nothing as read', (tester) async {
      final (h, notifications) = await _pumpApp(tester);

      h.push.opened.add(_classReminder);
      // Not pumpAndSettle: the timetable keeps a live indicator running.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(TimetablePage), findsOneWidget);
      expect(notifications.marked, isEmpty);
    });

    testWidgets('a class reminder received in the app shows its banner, the list stays',
        (tester) async {
      final (h, notifications) = await _pumpApp(tester);
      final loadsBefore = notifications.loads;

      h.push.foreground.add(_classReminder);
      await tester.pumpAndSettle();

      expect(find.text('Algorithmes & Complexité'), findsOneWidget);
      expect(notifications.loads, loadsBefore);
    });

    testWidgets('the push that started the app opens once the user is signed in',
        (tester) async {
      final (_, notifications) =
          await _pumpApp(tester, before: (h) => h.push.initialMessage = _accountPush);

      expect(find.byType(ProfilePage), findsOneWidget);
      expect(notifications.marked, ['room-change-gl']);
    });
  });
}
