# Home screen widgets

StatMaxxer can show an **OCR-free** home-screen widget fed only from local Drift data (via a SharedPreferences / App Group bridge). Native UI is required; Flutter cannot paint the widget itself.

## Approach

| Layer | Role |
|--------|------|
| Flutter | Computes today habits done/total, top streak, money net from existing Riverpod providers |
| `home_widget` | Writes keys into Android SharedPreferences / iOS App Group UserDefaults and triggers refresh |
| Android | `TodayWidgetProvider` + RemoteViews XML (`StatMaxxer Today`) |
| iOS | WidgetKit extension (scaffold below; needs Xcode + signing) |

Keys written by `HomeScreenWidgetSync`:

- `widget_title`
- `widget_habits`
- `widget_streak`
- `widget_money`

Sync runs on app resume and whenever the snapshot provider changes. Widgets do **not** read SQLite directly (keeps Drift schema ownership in the Flutter app).

## Android (working MVP)

1. Build/install a debug or release APK.
2. Long-press the home screen → **Widgets** → **StatMaxxer Today**.
3. Open the app once so Flutter pushes current numbers.
4. Tap the widget to open the app.

Native files:

- `android/.../TodayWidgetProvider.kt`
- `android/.../res/layout/statmaxxer_today_widget.xml`
- `android/.../res/xml/statmaxxer_today_widget_info.xml`

## iOS (WidgetKit scaffolding)

Flutter already calls `HomeWidget.setAppGroupId('group.com.statmaxxer.stat_maxxer')` and `updateWidget(iOSName: 'StatMaxxerTodayWidget')`. Completing iOS requires Xcode on a Mac:

1. Open `ios/Runner.xcworkspace` in Xcode.
2. **File → New → Target → Widget Extension**. Name it `StatMaxxerTodayWidget`. Uncheck “Include Configuration Intent” for the MVP.
3. Set the widget **kind** string to exactly `StatMaxxerTodayWidget` (must match Dart `HomeScreenWidgetSync.iOSName`).
4. Enable **App Groups** for both **Runner** and the widget extension:
   - Capability: App Groups
   - Group ID: `group.com.statmaxxer.stat_maxxer` (must match `HomeScreenWidgetSync.iOSAppGroupId`)
5. Replace the generated SwiftUI view with the reference in `ios/widget_scaffold/StatMaxxerTodayWidget.swift`.
6. Use the same Team / signing for Runner + extension; bump build numbers together.
7. Run on a device/simulator, add the widget from the iOS widget gallery, then open StatMaxxer once to populate UserDefaults.

Without steps 2–6, iOS builds still succeed — there is simply no widget extension yet.

## Sensible next widgets (later)

- Single-habit streak (pick habit in a configure activity / AppIntent)
- Month spend vs income
- Interactive “mark done” via `home_widget` background callbacks (more native work)

## Out of scope for this MVP

- Reading Drift/SQLite from the widget process
- Glance / Compose Android widgets (XML RemoteViews is enough for text)
- Background refresh while the app is never opened (would need WorkManager / BGAppRefresh)
