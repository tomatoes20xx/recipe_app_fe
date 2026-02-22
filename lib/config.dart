class Config {
  /// API base URL — set at build time via --dart-define=API_BASE_URL=...
  ///
  /// Defaults to Railway test backend for development.
  /// Override examples:
  ///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000        (local emulator)
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.0.103:3000   (local LAN device)
  static const String apiBaseUrl = String.fromEnvironment(
    "API_BASE_URL",
    defaultValue: "https://recipeappbe-testing.up.railway.app",
  );
}
