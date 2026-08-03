/// Compile-time feature flags (via `--dart-define`).
///
/// Example:
/// ```bash
/// flutter run --dart-define=ENABLE_GDRIVE_SYNC=true
/// ```
class FeatureFlags {
  FeatureFlags._();

  /// Google Drive sync UI and startup auth restore.
  ///
  /// Default **false** — Settings hides Drive sync; silent sign-in is skipped.
  /// Enable with `--dart-define=ENABLE_GDRIVE_SYNC=true`.
  static const enableGdriveSync = bool.fromEnvironment(
    'ENABLE_GDRIVE_SYNC',
    defaultValue: false,
  );
}
