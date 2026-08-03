import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/feature_flags.dart';
import '../../../core/providers.dart';
import '../../settings/presentation/currency_provider.dart';
import '../../settings/presentation/theme_provider.dart';
import '../data/drift_sync_local_store.dart';
import '../data/fake_drive_client.dart';
import '../data/google_drive_client.dart';
import '../data/google_oauth_config.dart';
import '../data/google_sync_auth.dart';
import '../data/sync_engine.dart';
import '../data/ttl_shard_cache.dart';
import '../domain/drive_client.dart';
import '../domain/sync_local_store.dart';
import '../domain/sync_status.dart';

final googleOAuthConfigProvider = Provider<GoogleOAuthConfig>((ref) {
  return GoogleOAuthConfig.fromEnvironment;
});

final googleSyncAuthProvider = Provider<GoogleSyncAuth>((ref) {
  return GoogleSyncAuth(config: ref.watch(googleOAuthConfigProvider));
});

final syncLocalStoreProvider = Provider<SyncLocalStore>((ref) {
  return DriftSyncLocalStore(
    db: ref.watch(appDatabaseProvider),
    prefs: ref.watch(sharedPreferencesProvider),
  );
});

final ttlShardCacheProvider = Provider<TtlShardCache>((ref) {
  return TtlShardCache(ttl: const Duration(days: 30));
});

/// When true, Sync Now uses [FakeDriveClient] (dry-run / no network).
final syncUseFakeDriveProvider =
    NotifierProvider<SyncUseFakeDriveNotifier, bool>(
  SyncUseFakeDriveNotifier.new,
);

class SyncUseFakeDriveNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setEnabled(bool value) => state = value;
}

final fakeDriveClientProvider = Provider<FakeDriveClient>((ref) {
  return FakeDriveClient();
});

class SyncController extends Notifier<SyncUiState> {
  @override
  SyncUiState build() {
    final auth = ref.watch(googleSyncAuthProvider);
    final prefs = ref.watch(sharedPreferencesProvider);
    final lastRaw = prefs.getString('sync_last_synced_at');
    final last = lastRaw == null ? null : DateTime.tryParse(lastRaw)?.toUtc();

    // Fire-and-forget restore of existing session (skip when flag off / OAuth unset).
    if (FeatureFlags.enableGdriveSync && auth.isConfigured) {
      Future.microtask(() async {
        await auth.initialize();
        final account = await auth.silentSignIn();
        if (!ref.mounted) return;
        if (account != null) {
          state = state.copyWith(
            signedIn: true,
            accountEmail: account.email,
            clearError: true,
          );
        }
      });
    }

    return SyncUiState(
      oauthConfigured: auth.isConfigured,
      signedIn: auth.isSignedIn,
      accountEmail: auth.currentAccount?.email,
      lastSyncedAt: last,
    );
  }

  GoogleSyncAuth get _auth => ref.read(googleSyncAuthProvider);

  Future<void> signIn() async {
    state = state.copyWith(
      phase: SyncPhase.signingIn,
      clearError: true,
      clearMessage: true,
    );
    try {
      final account = await _auth.signIn();
      state = state.copyWith(
        signedIn: account != null,
        accountEmail: account?.email,
        phase: SyncPhase.idle,
        message: account == null ? 'Sign-in cancelled' : 'Signed in',
        clearAccountEmail: account == null,
      );
    } catch (e) {
      state = state.copyWith(
        phase: SyncPhase.error,
        error: e.toString(),
        signedIn: false,
        clearAccountEmail: true,
      );
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    state = state.copyWith(
      signedIn: false,
      clearAccountEmail: true,
      phase: SyncPhase.idle,
      message: 'Signed out',
      clearError: true,
    );
  }

  Future<void> syncNow() async {
    final useFake = ref.read(syncUseFakeDriveProvider);
    if (!useFake && !_auth.isSignedIn) {
      state = state.copyWith(
        phase: SyncPhase.error,
        error: 'Sign in with Google before syncing.',
      );
      return;
    }

    state = state.copyWith(
      phase: SyncPhase.pulling,
      clearError: true,
      clearMessage: true,
    );

    try {
      final DriveClient drive;
      if (useFake) {
        drive = ref.read(fakeDriveClientProvider);
      } else {
        final token = await _auth.accessToken();
        if (token == null || token.isEmpty) {
          throw StateError('Missing Google access token');
        }
        drive = GoogleDriveClient(accessToken: token);
      }

      final engine = SyncEngine(
        localStore: ref.read(syncLocalStoreProvider),
        drive: drive,
        cache: ref.read(ttlShardCacheProvider),
        concurrency: 4,
      );

      state = state.copyWith(phase: SyncPhase.pushing);
      final result = await engine.sync();

      // Refresh theme/currency providers if settings shard changed.
      ref.invalidate(themeModeProvider);
      ref.invalidate(visualStyleProvider);
      ref.invalidate(currencyCodeProvider);

      state = state.copyWith(
        phase: SyncPhase.done,
        lastSyncedAt: result.finishedAt,
        message:
            'Synced — pulled ${result.pulled}, pushed ${result.pushed}, '
            'unchanged ${result.skipped}'
            '${useFake ? ' (fake Drive)' : ''}',
      );
      state = state.copyWith(phase: SyncPhase.idle);
    } catch (e) {
      state = state.copyWith(
        phase: SyncPhase.error,
        error: e.toString(),
      );
    }
  }
}

final syncControllerProvider =
    NotifierProvider<SyncController, SyncUiState>(SyncController.new);

/// Convenience for SharedPreferences in sync (already defined in theme_provider).
SharedPreferences syncPrefs(Ref ref) => ref.read(sharedPreferencesProvider);
