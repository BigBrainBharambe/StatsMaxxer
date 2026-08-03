# StatMaxxer

Local-first Flutter habit and money tracker for Android and iOS.

## Features

- **Habits** — daily check-ins, retroactive logging, current and best streaks
- **Money** — income and expense transactions with categories
- **Analytics** — weekday, monthly day-by-day, and yearly month charts
- **Themes** — light, dark, or system (persisted)
- **Home screen widget (Android MVP)** — today habits / top streak / money net from local data; iOS WidgetKit scaffold documented
- **Google Drive sync (MVP, flag-gated)** — sharded backup via Drive `appDataFolder`; off by default (`ENABLE_GDRIVE_SYNC`); see `docs/gdrive_sync.md`

## Stack

- Flutter + Riverpod
- Drift (SQLite) for local storage
- home_widget (SharedPreferences / App Group bridge to native widgets)
- google_sign_in + googleapis (Drive appDataFolder sync)
- fl_chart for analytics
- Domain logic covered by unit tests (TDD)

See [docs/home_screen_widgets.md](docs/home_screen_widgets.md) for Android usage and iOS Xcode steps.

See [docs/gdrive_sync.md](docs/gdrive_sync.md) for shard layout, TTL, conflicts, and OAuth client setup.

## Getting started

Flutter SDK is expected at `%USERPROFILE%\develop\flutter` (or any install on your `PATH`).

```bash
flutter pub get
dart run build_runner build
flutter test
flutter run
```

## Project layout

```
lib/
  core/           theme, database, providers
  features/
    habits/       domain, data, presentation
    money/        domain, data, presentation
    settings/     theme preference
    sync/         Google Drive sharded sync
    widgets/      home screen widget bridge
  shared/         home shell / navigation
test/
  features/       unit tests for streaks, analytics, repositories, sync
  widget_test.dart
```

### Enable Google Drive sync

```bash
flutter run ^
  --dart-define=ENABLE_GDRIVE_SYNC=true ^
  --dart-define=GOOGLE_OAUTH_CLIENT_ID=....apps.googleusercontent.com ^
  --dart-define=GOOGLE_OAUTH_SERVER_CLIENT_ID=....apps.googleusercontent.com
```

Without `ENABLE_GDRIVE_SYNC=true`, Settings hides Drive sync. Without OAuth
client IDs (but with the flag on), use **Settings → Fake Drive (dry-run)** —
see `docs/gdrive_sync.md`.
