/// OAuth client IDs for Google Sign-In / Drive.
///
/// Prefer compile-time defines (never commit secrets):
/// ```
/// flutter run \
///   --dart-define=GOOGLE_OAUTH_CLIENT_ID=....apps.googleusercontent.com \
///   --dart-define=GOOGLE_OAUTH_SERVER_CLIENT_ID=....apps.googleusercontent.com
/// ```
///
/// Android also needs the OAuth Android client SHA-1 registered in Google Cloud.
/// See docs/gdrive_sync.md.
class GoogleOAuthConfig {
  const GoogleOAuthConfig({
    this.clientId = '',
    this.serverClientId = '',
  });

  /// Platform OAuth client ID (iOS / desktop). Android often uses
  /// default google-services / SHA-registered client without passing clientId.
  final String clientId;

  /// Web client ID used as serverClientId for ID token / Drive scopes.
  final String serverClientId;

  static const fromEnvironment = GoogleOAuthConfig(
    clientId: String.fromEnvironment('GOOGLE_OAUTH_CLIENT_ID'),
    serverClientId: String.fromEnvironment('GOOGLE_OAUTH_SERVER_CLIENT_ID'),
  );

  bool get isConfigured =>
      clientId.trim().isNotEmpty || serverClientId.trim().isNotEmpty;

  /// Scopes required for appDataFolder sync (files invisible in My Drive UI).
  static const driveAppDataScope =
      'https://www.googleapis.com/auth/drive.appdata';
}
