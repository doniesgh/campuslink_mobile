import 'package:campuspulse/core/error/failures.dart';
import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/core/router/route_names.dart';
import 'package:campuspulse/core/theme/app_colors.dart';
import 'package:campuspulse/features/auth/domain/entities/user.dart';
import 'package:campuspulse/features/auth/domain/repositories/auth_repository.dart';
import 'package:campuspulse/features/auth/presentation/pages/reset_password_page.dart';
import 'package:campuspulse/features/auth/presentation/providers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/localized_app.dart';

/// Signed out; records reset and resend calls.
class _FakeAuthRepository implements AuthRepository {
  final resets = <(String, String, String)>[];
  final resends = <String>[];
  Failure? resetFailure;

  @override
  Future<Result<User?>> restoreSession() async => const Success(null);

  @override
  Future<Result<void>> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {
    resets.add((email, code, password));
    final failure = resetFailure;
    return failure == null ? const Success(null) : Err(failure);
  }

  @override
  Future<Result<void>> forgotPassword(String email) async {
    resends.add(email);
    return const Success(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_FakeAuthRepository> _pump(
  WidgetTester tester, {
  String email = 'sarra@campus.test',
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(375, 900) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final repository = _FakeAuthRepository();
  final router = GoRouter(
    initialLocation: RoutePaths.resetPasswordFor(email),
    routes: [
      GoRoute(
        path: RoutePaths.resetPassword,
        builder: (_, state) => ResetPasswordPage(email: state.uri.queryParameters['email'] ?? ''),
      ),
      GoRoute(
        path: RoutePaths.login,
        builder: (_, __) => const Scaffold(body: Text('Login screen')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(
        // Plain theme: the app theme pulls Google Fonts from the network.
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary)),
        routerConfig: router,
        locale: locale,
        supportedLocales: testSupportedLocales,
        localizationsDelegates: testLocalizationsDelegates,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

Future<void> _fill(WidgetTester tester, {required String code, required String password}) async {
  await tester.enterText(find.byType(TextFormField).at(0), code);
  await tester.enterText(find.byType(TextFormField).at(1), password);
  await tester.tap(find.text('Update password'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows where the code was sent', (tester) async {
    await _pump(tester);
    expect(find.text('Enter the 6-digit code sent to sarra@campus.test'), findsOneWidget);
  });

  testWidgets('validates the code and the password before calling the API', (tester) async {
    final repository = await _pump(tester);
    await _fill(tester, code: '12ab', password: 'short');

    expect(find.text('Enter the 6-digit code'), findsOneWidget);
    expect(find.text('Use at least 8 characters'), findsOneWidget);
    expect(repository.resets, isEmpty);
  });

  testWidgets('on success sends the email, code and password, then opens login', (tester) async {
    final repository = await _pump(tester);
    await _fill(tester, code: ' 123456 ', password: 'new-password-456');

    expect(repository.resets, [('sarra@campus.test', '123456', 'new-password-456')]);
    expect(find.text('Login screen'), findsOneWidget);
  });

  testWidgets('on failure shows the API message and stays', (tester) async {
    final repository = await _pump(tester);
    repository.resetFailure = const ValidationFailure('Invalid or expired code.');
    await _fill(tester, code: '123456', password: 'new-password-456');

    expect(find.text('Invalid or expired code.'), findsOneWidget);
    expect(find.text('Choose a new password'), findsOneWidget);
  });

  testWidgets('too many attempts is said in the app language', (tester) async {
    final repository = await _pump(tester, locale: const Locale('fr'));
    repository.resetFailure =
        const TooManyRequestsFailure('Too many attempts. Try again in a few minutes.');
    await _fill(tester, code: '123456', password: 'new-password-456');

    expect(find.text('Trop de tentatives. Réessaie dans quelques minutes.'), findsOneWidget);
  });

  testWidgets('"Send a new code" asks for another email', (tester) async {
    final repository = await _pump(tester);
    await tester.tap(find.text('Send a new code'));
    await tester.pumpAndSettle();

    expect(repository.resends, ['sarra@campus.test']);
    expect(find.text('A new code is on its way to sarra@campus.test.'), findsOneWidget);
  });
}
