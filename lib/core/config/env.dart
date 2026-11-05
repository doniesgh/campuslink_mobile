/// Build-time configuration injected with `--dart-define-from-file=env/<name>.json`.
abstract final class Env {
  static const String name = String.fromEnvironment("ENV", defaultValue: "dev");
  static const String apiBaseUrl = String.fromEnvironment(
    "API_BASE_URL",
    defaultValue: "http://10.0.2.2:3000/api", // Android emulator -> host machine
  );

  /// When true, fake data sources are used (no backend needed).
  static const bool useMock = bool.fromEnvironment("USE_MOCK", defaultValue: true);

  static bool get isProd => name == "prod";
}
