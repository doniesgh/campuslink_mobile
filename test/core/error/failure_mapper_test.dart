import 'dart:convert';
import 'dart:io';

import 'package:campuspulse/core/error/failure_mapper.dart';
import 'package:campuspulse/core/error/failure_text.dart';
import 'package:campuspulse/core/error/failures.dart';
import 'package:campuspulse/core/l10n/app_language.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_app.dart';

/// The 429 the API sends when a rate limit is hit (backend/test/rate-limit.test.ts).
final Map<String, dynamic> _rateLimited = (jsonDecode(
  File('test/features/admin/fixtures/admin_api.json').readAsStringSync(),
) as Map<String, dynamic>)['rateLimited'] as Map<String, dynamic>;

DioException _answer(int status, Object? body, {Map<String, List<String>>? headers}) {
  final request = RequestOptions(path: '/auth/login');
  return DioException.badResponse(
    statusCode: status,
    requestOptions: request,
    response: Response(
      requestOptions: request,
      statusCode: status,
      data: body,
      headers: Headers.fromMap(headers ?? {}),
    ),
  );
}

void main() {
  group('mapDioException', () {
    test('keeps the message and reads the code', () {
      final failure = mapDioException(
        _answer(422, {'message': 'Enter a name', 'code': 'VALIDATION_ERROR'}),
      );
      expect(failure, isA<ValidationFailure>());
      expect(failure.message, 'Enter a name');
      expect(failure.code, 'VALIDATION_ERROR');
    });

    test('an error without a code has none', () {
      final failure = mapDioException(_answer(404, {'message': 'Job not found.'}));
      expect(failure, isA<ServerFailure>());
      expect(failure.message, 'Job not found.');
      expect(failure.code, isNull);
    });

    test('codes reach 401s and server errors too', () {
      expect(mapDioException(_answer(401, {'message': 'Expired', 'code': 'TOKEN_EXPIRED'})).code,
          'TOKEN_EXPIRED');
      final ai = mapDioException(_answer(503, {'message': 'AI is off.', 'code': 'AI_UNAVAILABLE'}));
      expect(ai, isA<ServerFailure>());
      expect(ai.code, 'AI_UNAVAILABLE');
    });

    test('a 429 is a TooManyRequestsFailure with the server message and the wait', () {
      final failure = mapDioException(_answer(429, _rateLimited)) as TooManyRequestsFailure;
      expect(failure.message, 'Too many attempts. Try again in a few minutes.');
      expect(failure.code, 'TOO_MANY_REQUESTS');
      expect(failure.retryAfter, const Duration(seconds: 873));
    });

    test('a 429 without a body falls back to the header and a default message', () {
      final failure = mapDioException(_answer(429, '<html>Too Many Requests</html>', headers: {
        'retry-after': ['60'],
      })) as TooManyRequestsFailure;
      expect(failure.message, TooManyRequestsFailure.defaultMessage);
      expect(failure.code, 'TOO_MANY_REQUESTS');
      expect(failure.retryAfter, const Duration(minutes: 1));

      final bare = mapDioException(_answer(429, null)) as TooManyRequestsFailure;
      expect(bare.retryAfter, isNull);
    });

    test('a busy AI service is a 429 with its own code', () {
      final failure = mapDioException(_answer(429, {
        'message': 'The AI service is busy. Try again in a few minutes.',
        'code': 'AI_BUSY',
      }));
      expect(failure, isA<TooManyRequestsFailure>());
      expect(failure.code, 'AI_BUSY');
    });
  });

  group('failureText', () {
    Future<String Function(Object)> textIn(WidgetTester tester, AppLanguage language) async {
      late BuildContext context;
      await tester.pumpWidget(localizedApp(
        Builder(builder: (c) {
          context = c;
          return const SizedBox();
        }),
        language: language,
      ));
      return (error) => failureText(context, error);
    }

    testWidgets('translates the codes the app knows', (tester) async {
      const failure = TooManyRequestsFailure('Too many attempts. Try again in a few minutes.');

      expect((await textIn(tester, AppLanguage.fr))(failure),
          'Trop de tentatives. Réessaie dans quelques minutes.');
      expect((await textIn(tester, AppLanguage.en))(failure),
          'Too many attempts. Try again in a few minutes.');
    });

    testWidgets("shows the server's message for the other errors", (tester) async {
      final text = await textIn(tester, AppLanguage.fr);
      expect(text(const ValidationFailure('Enter a name', 'VALIDATION_ERROR')), 'Enter a name');
      expect(text(const ServerFailure('Job not found.')), 'Job not found.');
      expect(text(Exception('boom')), const UnknownFailure().message);
    });
  });
}
