import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import 'home_screen_widget_snapshot.dart';

/// Bridges Drift-derived summaries into native home-screen widgets via
/// [home_widget] SharedPreferences (Android) / App Group UserDefaults (iOS).
class HomeScreenWidgetSync {
  HomeScreenWidgetSync._();

  /// Must match Android `TodayWidgetProvider` and iOS WidgetKit kind (when added).
  static const androidQualifiedName =
      'com.statmaxxer.stat_maxxer.TodayWidgetProvider';
  static const androidName = 'TodayWidgetProvider';
  static const iOSName = 'StatMaxxerTodayWidget';

  /// App Group for iOS WidgetKit ↔ Flutter (configure in Xcode — see docs).
  static const iOSAppGroupId = 'group.com.statmaxxer.stat_maxxer';

  static const keyTitle = 'widget_title';
  static const keyHabits = 'widget_habits';
  static const keyStreak = 'widget_streak';
  static const keyMoney = 'widget_money';

  /// Writes [snapshot] and asks the OS to refresh the widget.
  ///
  /// Safe on desktop / tests: channel errors are swallowed.
  static Future<void> push(HomeScreenWidgetSnapshot snapshot) async {
    if (kIsWeb) return;
    if (!(Platform.isAndroid || Platform.isIOS)) return;

    try {
      if (Platform.isIOS) {
        await HomeWidget.setAppGroupId(iOSAppGroupId);
      }

      await HomeWidget.saveWidgetData<String>(keyTitle, snapshot.title);
      await HomeWidget.saveWidgetData<String>(keyHabits, snapshot.habitsLine);
      await HomeWidget.saveWidgetData<String>(keyStreak, snapshot.streakLine);
      await HomeWidget.saveWidgetData<String>(keyMoney, snapshot.moneyLine);

      await HomeWidget.updateWidget(
        name: androidName,
        androidName: androidName,
        qualifiedAndroidName: androidQualifiedName,
        iOSName: iOSName,
      );
    } catch (_) {
      // Method channel unavailable (unit tests, unsupported host).
    }
  }
}
