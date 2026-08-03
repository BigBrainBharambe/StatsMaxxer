enum SyncPhase {
  idle,
  signingIn,
  pulling,
  applying,
  pushing,
  done,
  error,
}

class SyncUiState {
  const SyncUiState({
    this.signedIn = false,
    this.accountEmail,
    this.lastSyncedAt,
    this.phase = SyncPhase.idle,
    this.message,
    this.error,
    this.oauthConfigured = false,
  });

  final bool signedIn;
  final String? accountEmail;
  final DateTime? lastSyncedAt;
  final SyncPhase phase;
  final String? message;
  final String? error;

  /// True when client IDs were provided via dart-define / config.
  final bool oauthConfigured;

  bool get isBusy =>
      phase == SyncPhase.signingIn ||
      phase == SyncPhase.pulling ||
      phase == SyncPhase.applying ||
      phase == SyncPhase.pushing;

  SyncUiState copyWith({
    bool? signedIn,
    String? accountEmail,
    DateTime? lastSyncedAt,
    SyncPhase? phase,
    String? message,
    String? error,
    bool? oauthConfigured,
    bool clearAccountEmail = false,
    bool clearLastSyncedAt = false,
    bool clearMessage = false,
    bool clearError = false,
  }) {
    return SyncUiState(
      signedIn: signedIn ?? this.signedIn,
      accountEmail:
          clearAccountEmail ? null : (accountEmail ?? this.accountEmail),
      lastSyncedAt:
          clearLastSyncedAt ? null : (lastSyncedAt ?? this.lastSyncedAt),
      phase: phase ?? this.phase,
      message: clearMessage ? null : (message ?? this.message),
      error: clearError ? null : (error ?? this.error),
      oauthConfigured: oauthConfigured ?? this.oauthConfigured,
    );
  }
}

class SyncResult {
  const SyncResult({
    required this.pulled,
    required this.pushed,
    required this.skipped,
    required this.finishedAt,
    this.warnings = const [],
  });

  final int pulled;
  final int pushed;
  final int skipped;
  final DateTime finishedAt;
  final List<String> warnings;
}
