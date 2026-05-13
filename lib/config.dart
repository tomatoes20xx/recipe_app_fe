class Config {
  /// API base URL — set at build time via --dart-define=API_BASE_URL=...
  ///
  /// Defaults to Railway test backend for development.
  /// Override examples:
  ///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000        (local emulator)
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.0.103:3000   (local LAN device)
  static const String apiBaseUrl = String.fromEnvironment(
    "API_BASE_URL",
    defaultValue: bool.fromEnvironment('dart.vm.product')
        ? "https://recipeappbe-production-4692.up.railway.app"
        : "https://recipeappbe-testing.up.railway.app",
  );

  /// Google Sign-In Web Client ID — set at build time via --dart-define=GOOGLE_WEB_CLIENT_ID=...
  /// Note: OAuth client IDs are public by design but should be set explicitly in CI/CD.
  /// Override: flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=<id>
  static const String googleWebClientId = String.fromEnvironment(
    "GOOGLE_WEB_CLIENT_ID",
    defaultValue: "31640311657-vt82s1udbrrn2t36g3ivhh0jll148q4l.apps.googleusercontent.com",
  );

  /// Google Sign-In iOS Client ID — set at build time via --dart-define=GOOGLE_IOS_CLIENT_ID=...
  /// Must match CLIENT_ID in GoogleService-Info.plist.
  /// Override: flutter run --dart-define=GOOGLE_IOS_CLIENT_ID=<id>
  static const String googleIosClientId = String.fromEnvironment(
    "GOOGLE_IOS_CLIENT_ID",
    defaultValue: "31640311657-m9hij53r5o802ipotb3edkcd7kqqsjt2.apps.googleusercontent.com",
  );
}
