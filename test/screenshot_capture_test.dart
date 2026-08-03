import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stat_maxxer/core/providers.dart';
import 'package:stat_maxxer/core/theme/app_theme.dart';
import 'package:stat_maxxer/core/utils/date_utils.dart';
import 'package:stat_maxxer/features/habits/data/in_memory_habit_repository.dart';
import 'package:stat_maxxer/features/habits/domain/habit.dart';
import 'package:stat_maxxer/features/habits/domain/habit_occurrence.dart';
import 'package:stat_maxxer/features/habits/presentation/habits_screen.dart';
import 'package:stat_maxxer/features/money/data/in_memory_transaction_repository.dart';
import 'package:stat_maxxer/features/money/data/in_memory_wishlist_repository.dart';
import 'package:stat_maxxer/features/money/domain/transaction.dart';
import 'package:stat_maxxer/features/money/presentation/analytics_screen.dart';
import 'package:stat_maxxer/features/money/presentation/money_screen.dart';
import 'package:stat_maxxer/features/settings/presentation/settings_screen.dart';
import 'package:stat_maxxer/features/settings/presentation/theme_provider.dart';

final _boundaryKey = GlobalKey();

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary = _boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('screenshots');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    await File('screenshots/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
  });
}

Future<ProviderContainer> _seededContainer({
  ThemeMode theme = ThemeMode.light,
}) async {
  SharedPreferences.setMockInitialValues({
    'theme_mode': switch (theme) {
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
    },
  });
  final prefs = await SharedPreferences.getInstance();
  final habits = InMemoryHabitRepository();
  final money = InMemoryTransactionRepository();
  final wishlist = InMemoryWishlistRepository();
  final today = dateOnly(DateTime.now());

  await habits.addHabit(
    Habit(
      id: 'h1',
      name: 'Exercise',
      createdAt: DateTime(2026, 1, 1),
      schedule: HabitSchedule.daily(),
    ),
  );
  await habits.addHabit(
    Habit(
      id: 'h2',
      name: 'Read 20 pages',
      createdAt: DateTime(2026, 1, 2),
      schedule: HabitSchedule.daily(),
    ),
  );
  for (var i = 0; i < 4; i++) {
    final day = today.subtract(Duration(days: i));
    await habits.upsertOccurrence(
      HabitOccurrence(
        id: 'h1-$i',
        habitId: 'h1',
        dueAt: day,
        status: OccurrenceStatus.completed,
        completedAt: day,
      ),
    );
  }
  await habits.upsertOccurrence(
    HabitOccurrence(
      id: 'h2-0',
      habitId: 'h2',
      dueAt: today,
      status: OccurrenceStatus.completed,
      completedAt: today,
    ),
  );

  await money.addTransaction(
    MoneyTransaction(
      id: 't1',
      amount: 3200,
      type: TransactionType.income,
      category: 'Salary',
      date: today.subtract(const Duration(days: 2)),
      note: 'July pay',
    ),
  );
  await money.addTransaction(
    MoneyTransaction(
      id: 't2',
      amount: 18.5,
      type: TransactionType.expense,
      category: 'Food',
      date: today,
      note: 'Lunch',
    ),
  );
  await money.addTransaction(
    MoneyTransaction(
      id: 't3',
      amount: 42,
      type: TransactionType.expense,
      category: 'Transport',
      date: today.subtract(const Duration(days: 1)),
    ),
  );
  await money.addTransaction(
    MoneyTransaction(
      id: 't4',
      amount: 65,
      type: TransactionType.expense,
      category: 'Shopping',
      date: today.subtract(const Duration(days: 3)),
    ),
  );

  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      habitRepositoryProvider.overrideWithValue(habits),
      transactionRepositoryProvider.overrideWithValue(money),
      wishlistRepositoryProvider.overrideWithValue(wishlist),
    ],
  );
}

Future<void> _pumpScreen(
  WidgetTester tester,
  ProviderContainer container,
  Widget screen, {
  required ThemeMode themeMode,
  required int navIndex,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: RepaintBoundary(
        key: _boundaryKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          home: Scaffold(
            body: screen,
            bottomNavigationBar: NavigationBar(
              selectedIndex: navIndex,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.check_circle_outline),
                  selectedIcon: Icon(Icons.check_circle),
                  label: 'Habits',
                ),
                NavigationDestination(
                  icon: Icon(Icons.payments_outlined),
                  selectedIcon: Icon(Icons.payments),
                  label: 'Money',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: 'Analytics',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture app screenshots', (tester) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    await binding.setSurfaceSize(const Size(390, 844));
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;

    var container = await _seededContainer();
    await _pumpScreen(
      tester,
      container,
      const HabitsScreen(),
      themeMode: ThemeMode.light,
      navIndex: 0,
    );
    await _capture(tester, '01_habits_light');

    await _pumpScreen(
      tester,
      container,
      const MoneyScreen(),
      themeMode: ThemeMode.light,
      navIndex: 1,
    );
    await _capture(tester, '02_money_light');

    await _pumpScreen(
      tester,
      container,
      const AnalyticsScreen(),
      themeMode: ThemeMode.light,
      navIndex: 2,
    );
    await _capture(tester, '03_analytics_light');

    await _pumpScreen(
      tester,
      container,
      const SettingsScreen(),
      themeMode: ThemeMode.light,
      navIndex: 3,
    );
    await _capture(tester, '04_settings_light');
    container.dispose();

    container = await _seededContainer(theme: ThemeMode.dark);
    await _pumpScreen(
      tester,
      container,
      const HabitsScreen(),
      themeMode: ThemeMode.dark,
      navIndex: 0,
    );
    await _capture(tester, '05_habits_dark');

    await _pumpScreen(
      tester,
      container,
      const MoneyScreen(),
      themeMode: ThemeMode.dark,
      navIndex: 1,
    );
    await _capture(tester, '06_money_dark');
    container.dispose();

    addTearDown(() async {
      await binding.setSurfaceSize(null);
    });
  });
}
