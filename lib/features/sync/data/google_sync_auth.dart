import 'package:google_sign_in/google_sign_in.dart';

import 'google_oauth_config.dart';

class SyncAuthAccount {
  const SyncAuthAccount({
    required this.email,
    required this.displayName,
    required this.accessToken,
  });

  final String email;
  final String? displayName;
  final String accessToken;
}

/// Google Sign-In wrapper; safe when OAuth is not configured.
class GoogleSyncAuth {
  GoogleSyncAuth({
    GoogleOAuthConfig? config,
    GoogleSignIn? signIn,
  })  : _config = config ?? GoogleOAuthConfig.fromEnvironment,
        _signIn = signIn;

  final GoogleOAuthConfig _config;
  GoogleSignIn? _signIn;
  SyncAuthAccount? _account;

  bool get isConfigured => _config.isConfigured;
  SyncAuthAccount? get currentAccount => _account;
  bool get isSignedIn => _account != null;

  GoogleSignIn get _client {
    return _signIn ??= GoogleSignIn.instance;
  }

  Future<void> initialize() async {
    if (!isConfigured) return;
    try {
      await _client.initialize(
        clientId: _config.clientId.isEmpty ? null : _config.clientId,
        serverClientId: _config.serverClientId.isEmpty
            ? null
            : _config.serverClientId,
      );
    } catch (_) {
      // Platforms without Sign-In support (e.g. some desktop builds).
    }
  }

  Future<SyncAuthAccount?> signIn() async {
    if (!isConfigured) {
      throw StateError(
        'Google OAuth is not configured. Pass GOOGLE_OAUTH_CLIENT_ID / '
        'GOOGLE_OAUTH_SERVER_CLIENT_ID via --dart-define. See docs/gdrive_sync.md.',
      );
    }
    await initialize();
    final account = await _client.authenticate(
      scopeHint: const [GoogleOAuthConfig.driveAppDataScope],
    );
    final auth = account.authorizationClient;
    final clientAuth = await auth.authorizationForScopes(
      const [GoogleOAuthConfig.driveAppDataScope],
    );
    final token = clientAuth?.accessToken;
    if (token == null || token.isEmpty) {
      final prompted = await auth.authorizeScopes(
        const [GoogleOAuthConfig.driveAppDataScope],
      );
      _account = SyncAuthAccount(
        email: account.email,
        displayName: account.displayName,
        accessToken: prompted.accessToken,
      );
    } else {
      _account = SyncAuthAccount(
        email: account.email,
        displayName: account.displayName,
        accessToken: token,
      );
    }
    return _account;
  }

  Future<SyncAuthAccount?> silentSignIn() async {
    if (!isConfigured) return null;
    await initialize();
    try {
      final future = _client.attemptLightweightAuthentication();
      if (future == null) return null;
      final account = await future;
      if (account == null) return null;
      final auth = account.authorizationClient;
      final clientAuth = await auth.authorizationForScopes(
        const [GoogleOAuthConfig.driveAppDataScope],
      );
      if (clientAuth == null) return null;
      _account = SyncAuthAccount(
        email: account.email,
        displayName: account.displayName,
        accessToken: clientAuth.accessToken,
      );
      return _account;
    } catch (_) {
      return null;
    }
  }

  Future<void> signOut() async {
    _account = null;
    if (!isConfigured) return;
    try {
      await _client.signOut();
    } catch (_) {}
  }

  Future<String?> accessToken() async {
    if (_account != null) return _account!.accessToken;
    final silent = await silentSignIn();
    return silent?.accessToken;
  }
}
