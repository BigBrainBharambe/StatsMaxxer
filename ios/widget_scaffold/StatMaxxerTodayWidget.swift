import WidgetKit
import SwiftUI

/// Reference WidgetKit implementation for StatMaxxer.
///
/// Do not compile this file from the Flutter Runner target.
/// Add a Widget Extension in Xcode and copy this into that target.
/// See docs/home_screen_widgets.md for App Group + signing steps.
///
/// Kind must stay: StatMaxxerTodayWidget
/// App Group must stay: group.com.statmaxxer.stat_maxxer

private let appGroupId = "group.com.statmaxxer.stat_maxxer"

struct StatMaxxerTodayEntry: TimelineEntry {
  let date: Date
  let title: String
  let habits: String
  let streak: String
  let money: String
}

struct StatMaxxerTodayProvider: TimelineProvider {
  func placeholder(in context: Context) -> StatMaxxerTodayEntry {
    StatMaxxerTodayEntry(
      date: Date(),
      title: "Today",
      habits: "—/— done",
      streak: "Top streak: —",
      money: "Net: —"
    )
  }

  func getSnapshot(in context: Context, completion: @escaping (StatMaxxerTodayEntry) -> Void) {
    completion(loadEntry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<StatMaxxerTodayEntry>) -> Void) {
    let entry = loadEntry()
    completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60))))
  }

  private func loadEntry() -> StatMaxxerTodayEntry {
    let defaults = UserDefaults(suiteName: appGroupId)
    return StatMaxxerTodayEntry(
      date: Date(),
      title: defaults?.string(forKey: "widget_title") ?? "Today",
      habits: defaults?.string(forKey: "widget_habits") ?? "Open StatMaxxer to sync",
      streak: defaults?.string(forKey: "widget_streak") ?? "Top streak: —",
      money: defaults?.string(forKey: "widget_money") ?? "Net: —"
    )
  }
}

struct StatMaxxerTodayWidgetView: View {
  var entry: StatMaxxerTodayEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(entry.title).font(.headline)
      Text(entry.habits).font(.title3).bold()
      Text(entry.streak).font(.caption)
      Text(entry.money).font(.caption)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .padding()
  }
}

struct StatMaxxerTodayWidget: Widget {
  let kind: String = "StatMaxxerTodayWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: StatMaxxerTodayProvider()) { entry in
      StatMaxxerTodayWidgetView(entry: entry)
    }
    .configurationDisplayName("StatMaxxer Today")
    .description("Today habits, top streak, and money net.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
