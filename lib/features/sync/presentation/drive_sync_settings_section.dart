import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../settings/presentation/theme_provider.dart';
import '../domain/sync_status.dart';
import 'sync_providers.dart';

/// Settings section for Google Drive sync (sign-in, sync now, status).
class DriveSyncSettingsSection extends ConsumerWidget {
  const DriveSyncSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(visualStyleProvider);
    final isCyber = style == VisualStyle.cyber;
    final sync = ref.watch(syncControllerProvider);
    final useFake = ref.watch(syncUseFakeDriveProvider);

    final lastLabel = sync.lastSyncedAt == null
        ? (isCyber ? 'NEVER' : 'Never')
        : DateFormat.yMMMd().add_jm().format(sync.lastSyncedAt!.toLocal());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        ListTile(
          title: Text(isCyber ? 'GOOGLE DRIVE SYNC' : 'Google Drive sync'),
          subtitle: Text(
            isCyber
                ? 'BACKUP / MULTI-DEVICE VIA APPDATAFOLDER SHARDS\n'
                    'SEE DOCS/GDRIVE_SYNC.MD'
                : 'Backup and multi-device sync using Drive appDataFolder '
                    'shards. See docs/gdrive_sync.md for OAuth setup.',
          ),
          isThreeLine: true,
        ),
        if (!sync.oauthConfigured && !useFake)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              isCyber
                  ? 'OAUTH NOT CONFIGURED — PASS CLIENT IDS VIA '
                      '--DART-DEFINE OR ENABLE FAKE DRIVE BELOW'
                  : 'OAuth not configured. Pass GOOGLE_OAUTH_CLIENT_ID / '
                      'GOOGLE_OAUTH_SERVER_CLIENT_ID via --dart-define, '
                      'or enable Fake Drive for a local dry-run.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        SwitchListTile(
          title: Text(isCyber ? 'FAKE DRIVE (DRY-RUN)' : 'Fake Drive (dry-run)'),
          subtitle: Text(
            isCyber
                ? 'IN-MEMORY DRIVE — NO GOOGLE ACCOUNT NEEDED'
                : 'Uses an in-memory Drive client (no Google account).',
          ),
          value: useFake,
          onChanged: sync.isBusy
              ? null
              : (v) => ref
                  .read(syncUseFakeDriveProvider.notifier)
                  .setEnabled(v),
        ),
        ListTile(
          leading: Icon(
            sync.signedIn || useFake
                ? Icons.cloud_done_outlined
                : Icons.cloud_off_outlined,
          ),
          title: Text(
            useFake
                ? (isCyber ? 'FAKE DRIVE READY' : 'Fake Drive ready')
                : sync.signedIn
                    ? (sync.accountEmail ??
                        (isCyber ? 'SIGNED IN' : 'Signed in'))
                    : (isCyber ? 'NOT SIGNED IN' : 'Not signed in'),
          ),
          subtitle: Text(
            isCyber ? 'LAST SYNCED: $lastLabel' : 'Last synced: $lastLabel',
          ),
        ),
        if (sync.message != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              sync.message!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (sync.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              sync.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!useFake && !sync.signedIn)
                FilledButton.icon(
                  onPressed: sync.isBusy || !sync.oauthConfigured
                      ? null
                      : () =>
                          ref.read(syncControllerProvider.notifier).signIn(),
                  icon: sync.phase == SyncPhase.signingIn
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(
                    isCyber ? 'SIGN IN WITH GOOGLE' : 'Sign in with Google',
                  ),
                ),
              if (!useFake && sync.signedIn) ...[
                OutlinedButton.icon(
                  onPressed: sync.isBusy
                      ? null
                      : () =>
                          ref.read(syncControllerProvider.notifier).signOut(),
                  icon: const Icon(Icons.logout),
                  label: Text(isCyber ? 'SIGN OUT' : 'Sign out'),
                ),
                const SizedBox(height: 8),
              ],
              if (!useFake && !sync.signedIn) const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: sync.isBusy || (!useFake && !sync.signedIn)
                    ? null
                    : () =>
                        ref.read(syncControllerProvider.notifier).syncNow(),
                icon: sync.isBusy && sync.phase != SyncPhase.signingIn
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: Text(isCyber ? 'SYNC NOW' : 'Sync now'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
