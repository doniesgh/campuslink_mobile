import 'dart:convert';
import 'dart:typed_data';

import 'package:campuspulse/core/network/interceptors/locale_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers `{}` to every request and records the headers sent.
class _Recorder implements HttpClientAdapter {
  final headers = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    headers.add(Map.of(options.headers));
    return ResponseBody.fromString(jsonEncode({}), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test("sends the app's language, as it is at each request", () async {
    var language = 'fr';
    final recorder = _Recorder();
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api'))
      ..httpClientAdapter = recorder
      ..interceptors.add(LocaleInterceptor(() => language));

    await dio.get('/users/me');
    language = 'en';
    await dio.post('/auth/forgot-password', data: {'email': 'a@b.c'});

    expect(recorder.headers.map((h) => h['Accept-Language']), ['fr', 'en']);
  });

  test('a request that sets the header keeps its own', () async {
    final recorder = _Recorder();
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api'))
      ..httpClientAdapter = recorder
      ..interceptors.add(LocaleInterceptor(() => 'fr'));

    await dio.get('/health', options: Options(headers: {'accept-language': 'en'}));

    final sent = recorder.headers.single.entries
        .where((header) => header.key.toLowerCase() == 'accept-language')
        .map((header) => header.value);
    expect(sent, ['en']);
  });
}
