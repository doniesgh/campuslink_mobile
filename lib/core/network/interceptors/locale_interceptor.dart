import 'package:dio/dio.dart';

/// Sends the app's language (`fr` or `en`) as `Accept-Language` on every
/// request, so the server can answer in it before it knows the user (sign-up,
/// password reset). A request that sets the header itself keeps its own.
class LocaleInterceptor extends Interceptor {
  LocaleInterceptor(this.languageCode);

  /// Read at each request: the language can change while the app runs.
  final String Function() languageCode;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final hasOwn = options.headers.keys.any((k) => k.toLowerCase() == 'accept-language');
    if (!hasOwn) options.headers['Accept-Language'] = languageCode();
    handler.next(options);
  }
}
