# Google Drive sync (sharded)

Local-first StatMaxxer keeps Drift SQLite as the source of truth on each
device. Google Drive `appDataFolder` holds a **sharded backup** for restore and
multi-device sync. Files live in the hidden app data space — they do **not**
clutter the user’s My Drive UI.

## Feature flag (default off)

Drive sync UI and startup session restore are gated by
`ENABLE_GDRIVE_SYNC` (see `lib/core/feature_flags.dart`). **Default is
false** — Settings does not show Google Drive sync / Fake Drive, and silent
sign-in does not run. Sync engine code stays in the tree for when you need it.

```bash
flutter run --dart-define=ENABLE_GDRIVE_SYNC=true
```

With OAuth client IDs (when using real Drive):

```bash
flutter run ^
  --dart-define=ENABLE_GDRIVE_SYNC=true ^
  --dart-define=GOOGLE_OAUTH_CLIENT_ID=YOUR_IOS_OR_DESKTOP_CLIENT.apps.googleusercontent.com ^
  --dart-define=GOOGLE_OAUTH_SERVER_CLIENT_ID=YOUR_WEB_CLIENT.apps.googleusercontent.com
```

Use the same `--dart-define=ENABLE_GDRIVE_SYNC=true` for `flutter build` /
`flutter test` if those runs should exercise the Settings Drive section.

## Shard map

| Path | Contents |
|------|----------|
| `manifest.json` | Schema version, device id, `lastSyncAt`, per-shard checksum + `updatedAt` (+ optional etag) |
| `meta/habits.json` | Habit definitions (schedule / goals / icons) |
| `meta/settings.json` | Theme mode, visual style, currency |
| `meta/wishlist.json` | All wishlist items (open + bought) |
| `money/yyyy/MM.json` | Transactions for that calendar month (`date`) |
| `habits/occurrences/yyyy/MM.json` | Habit occurrences for that month (`dueAt`) |
| `habits/quantity/yyyy/MM.json` | Quantity logs for that month (`loggedAt`) |

On Drive, logical paths are stored as flat names (`money__2026__07.json`) with
`appProperties.path` set to the logical path above.

Shard envelope:

```json
{
  "schemaVersion": 1,
  "kind": "money",
  "path": "money/2026/07.json",
  "updatedAt": "2026-08-02T12:00:00.000Z",
  "items": [ /* entity maps */ ]
}
```

Checksum = SHA-256 of `{kind, path, items}` (excludes `updatedAt`).

## TTL (local cache)

`TtlShardCache` keeps recently fetched/pushed shard bytes in memory.

- Default TTL: **30 days** since last access
- Max entries: **256** (oldest inserted evicted first)
- Expired shards are dropped locally only; **Drive copies remain**
- Next sync or demand re-fetches from Drive

## Parallelism

Pull and push use a bounded pool (`runBoundedParallel`, default **concurrency = 4**).
Only shards that differ (per conflict rules) are transferred.

## Conflict rules (v1 — not a CRDT)

**Last-write-wins per shard** using `updatedAt`, with checksum short-circuit:

1. Same checksum → skip
2. Only on remote → pull
3. Only on local → push
4. Both differ → higher `updatedAt` wins; tie → prefer remote

A **local shard index** (SharedPreferences) remembers checksums after each
successful sync so unchanged content keeps its previous `updatedAt` (avoids
force-pushing everything after a pull).

**Limitations**

- No field-level merge; concurrent edits in the same month shard can lose data
- No tombstone log beyond “missing from meta snapshot ⇒ deleted”
- Habit delete on one device removes that habit (and cascades occurrences) when
  the meta shard wins
- Pending future occurrences should be re-materialized via `syncAllHabits()` after
  restore (same as cold start)

## OAuth setup (Google Cloud)

1. Create a project in [Google Cloud Console](https://console.cloud.google.com/)
2. Enable **Google Drive API**
3. Configure OAuth consent screen (External / Testing is fine for personal use)
4. Create credentials:
   - **Android**: OAuth client with package `…` + SHA-1 of your debug/release keystore
   - **Web** (recommended as `serverClientId` for ID token / scopes)
   - **iOS / Desktop** client IDs if you target those platforms
5. Scope used: `https://www.googleapis.com/auth/drive.appdata`

### Pass client IDs (never commit secrets)

```bash
flutter run ^
  --dart-define=GOOGLE_OAUTH_CLIENT_ID=YOUR_IOS_OR_DESKTOP_CLIENT.apps.googleusercontent.com ^
  --dart-define=GOOGLE_OAUTH_SERVER_CLIENT_ID=YOUR_WEB_CLIENT.apps.googleusercontent.com
```

Android often works with the SHA-registered Android client without passing
`GOOGLE_OAUTH_CLIENT_ID`; still set `GOOGLE_OAUTH_SERVER_CLIENT_ID` (Web client)
when the Sign-In plugin requires it for tokens.

Optional local file `lib/features/sync/data/google_oauth_local.dart` is
gitignored if you prefer a compile-time override — prefer dart-define in CI.

### Windows / desktop

`google_sign_in` support varies by platform. If interactive Sign-In is
unsupported, Settings still compiles: use **Fake Drive (dry-run)** or add a
desktop OAuth flow later. Android is the primary real-Drive target for MVP.

## Settings UI

Visible only when `ENABLE_GDRIVE_SYNC=true`.

**Settings → Google Drive sync**

- Sign in with Google / Sign out
- Sync now
- Last synced timestamp + status / errors
- Fake Drive (dry-run) toggle — in-memory Drive, no OAuth

## MVP vs later

**MVP (this change)**

- Shard codec + monthly split/merge
- TTL cache + bounded parallel pull/push
- LWW conflict + local index
- Fake Drive tests + real `GoogleDriveClient` behind `DriveClient`
- Settings section

**Later**

- Background / periodic sync
- Append-only logs or per-entity `updatedAt` merge
- Desktop browser OAuth
- Selective month restore UI
- Encrypt shards at rest on Drive

## Code map

| Area | Path |
|------|------|
| Engine | `lib/features/sync/data/sync_engine.dart` |
| Fake Drive | `lib/features/sync/data/fake_drive_client.dart` |
| Google Drive | `lib/features/sync/data/google_drive_client.dart` |
| Drift bridge | `lib/features/sync/data/drift_sync_local_store.dart` |
| UI | `lib/features/sync/presentation/` |
| Feature flag | `lib/core/feature_flags.dart` (`ENABLE_GDRIVE_SYNC`) |
| Tests | `test/features/sync/` |
