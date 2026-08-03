import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers.dart';
import '../../../core/utils/date_utils.dart';
import '../domain/habit.dart';
import '../domain/habit_occurrence.dart';
import '../domain/habit_quantity_log.dart';
import '../domain/habit_retro_rules.dart';
import '../domain/occurrence_day_collapse.dart';
import '../domain/quantity_window_goal.dart';
import '../domain/quantity_window_streak_calculator.dart';
import '../domain/streak_calculator.dart';
import '../services/habit_notification_scheduler.dart';

const _uuid = Uuid();
const _streakCalculator = StreakCalculator();
const _quantityStreakCalculator = QuantityWindowStreakCalculator();

final habitNotificationSchedulerProvider =
    Provider<HabitNotificationScheduler>((ref) {
  final scheduler = HabitNotificationScheduler();
  ref.onDispose(() {});
  return scheduler;
});

final habitsProvider = StreamProvider<List<Habit>>((ref) {
  return ref.watch(habitRepositoryProvider).watchHabits();
});

final habitOccurrencesProvider =
    StreamProvider.family<List<HabitOccurrence>, String>((ref, habitId) {
  return ref.watch(habitRepositoryProvider).watchOccurrences(habitId).map(
        // Always one row per calendar day so Done/Undo match streak chips.
        (list) => collapseOccurrencesByCalendarDay(list).reversed.toList(),
      );
});

final habitQuantityLogsProvider =
    StreamProvider.family<List<HabitQuantityLog>, String>((ref, habitId) {
  return ref.watch(habitRepositoryProvider).watchQuantityLogs(habitId);
});

final allOccurrencesProvider = StreamProvider<List<HabitOccurrence>>((ref) {
  final from = dateOnly(DateTime.now()).subtract(const Duration(days: 400));
  final to = dateOnly(DateTime.now()).add(const Duration(days: 90));
  return ref
      .watch(habitRepositoryProvider)
      .watchAllOccurrences(from: from, to: to)
      .map(collapseOccurrencesByHabitAndDay);
});

final allQuantityLogsProvider = StreamProvider<List<HabitQuantityLog>>((ref) {
  final from = dateOnly(DateTime.now()).subtract(const Duration(days: 400));
  final to = dateOnly(DateTime.now()).add(const Duration(days: 2));
  return ref
      .watch(habitRepositoryProvider)
      .watchAllQuantityLogs(from: from, to: to);
});

/// Calendar marker for a quantity habit on one calendar day.
class QuantityCalendarDayMark {
  const QuantityCalendarDayMark({
    required this.habit,
    required this.loggedQuantity,
    required this.success,
  });

  final Habit habit;
  final num loggedQuantity;
  final bool success;

  bool get hasLog => loggedQuantity > 0;
}

final habitStreakProvider =
    Provider.family<AsyncValue<({int current, int best})>, String>(
        (ref, habitId) {
  final habitsAsync = ref.watch(habitsProvider);
  return habitsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
    data: (habits) {
      final habit = habits.where((h) => h.id == habitId).firstOrNull;
      if (habit == null) {
        return const AsyncValue.data((current: 0, best: 0));
      }

      if (habit.isQuantityGoal) {
        final logsAsync = ref.watch(habitQuantityLogsProvider(habitId));
        return logsAsync.whenData((logs) {
          final result = _quantityStreakCalculator.calculate(
            goal: habit.quantityGoal!,
            logs: logs,
            now: DateTime.now(),
            // Include the pre-creation retro window so past logs update streaks.
            since: earliestRetroDate(habit.createdAt),
          );
          return (current: result.current, best: result.best);
        });
      }

      final occAsync = ref.watch(habitOccurrencesProvider(habitId));
      return occAsync.whenData((occurrences) {
        final result = _streakCalculator.calculate(
          occurrences,
          today: dateOnly(DateTime.now()),
        );
        return (current: result.current, best: result.best);
      });
    },
  );
});

final habitQuantityProgressProvider =
    Provider.family<AsyncValue<QuantityWindowProgress?>, String>(
        (ref, habitId) {
  final habitsAsync = ref.watch(habitsProvider);
  final habit = habitsAsync.asData?.value
      .where((h) => h.id == habitId)
      .firstOrNull;
  if (habit == null || !habit.isQuantityGoal) {
    return const AsyncValue.data(null);
  }
  final logsAsync = ref.watch(habitQuantityLogsProvider(habitId));
  return logsAsync.whenData((logs) {
    return _quantityStreakCalculator.progress(
      goal: habit.quantityGoal!,
      logs: logs,
      now: DateTime.now(),
    );
  });
});

final topStreakProvider = Provider<AsyncValue<int>>((ref) {
  final habitsAsync = ref.watch(habitsProvider);
  return habitsAsync.when(
    data: (habits) {
      var best = 0;
      for (final h in habits) {
        final s = ref.watch(habitStreakProvider(h.id)).asData?.value.current ?? 0;
        if (s > best) best = s;
      }
      return AsyncValue.data(best);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

class TodayQuest {
  const TodayQuest({
    required this.habit,
    this.occurrence,
  });

  final Habit habit;

  /// Null for quantity-window habits (no scheduled due).
  final HabitOccurrence? occurrence;

  bool get isQuantity => habit.isQuantityGoal;
}

final todayQuestsProvider = Provider<AsyncValue<List<TodayQuest>>>((ref) {
  final habitsAsync = ref.watch(habitsProvider);
  final occAsync = ref.watch(allOccurrencesProvider);
  if (habitsAsync.isLoading || occAsync.isLoading) {
    return const AsyncValue.loading();
  }
  if (habitsAsync.hasError) {
    return AsyncValue.error(habitsAsync.error!, habitsAsync.stackTrace!);
  }
  if (occAsync.hasError) {
    return AsyncValue.error(occAsync.error!, occAsync.stackTrace!);
  }

  final habits = {for (final h in habitsAsync.requireValue) h.id: h};
  final today = dateOnly(DateTime.now());
  final quests = <TodayQuest>[];

  for (final h in habits.values) {
    if (h.archived) continue;
    if (h.isQuantityGoal) {
      quests.add(TodayQuest(habit: h));
    }
  }

  for (final o in occAsync.requireValue) {
    if (!isSameDay(o.dueAt, today)) continue;
    final habit = habits[o.habitId];
    if (habit == null || habit.archived || habit.isQuantityGoal) continue;
    quests.add(TodayQuest(habit: habit, occurrence: o));
  }

  quests.sort((a, b) {
    int statusRank(TodayQuest q) {
      if (q.isQuantity) {
        final progress =
            ref.watch(habitQuantityProgressProvider(q.habit.id)).asData?.value;
        return progress?.met == true ? 3 : 0;
      }
      final status = q.occurrence!.status;
      return switch (status) {
        OccurrenceStatus.pending => 0,
        OccurrenceStatus.missed => 1,
        OccurrenceStatus.skipped => 2,
        OccurrenceStatus.completed => 3,
      };
    }

    final cmp = statusRank(a).compareTo(statusRank(b));
    if (cmp != 0) return cmp;
    return a.habit.name.compareTo(b.habit.name);
  });
  return AsyncValue.data(quests);
});

final calendarMonthProvider =
    NotifierProvider<CalendarMonthNotifier, DateTime>(CalendarMonthNotifier.new);

class CalendarMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void setMonth(DateTime month) => state = DateTime(month.year, month.month);

  void prev() => state = DateTime(state.year, state.month - 1);

  void next() => state = DateTime(state.year, state.month + 1);
}

final calendarFilterHabitIdProvider =
    NotifierProvider<CalendarFilterNotifier, String?>(
  CalendarFilterNotifier.new,
);

class CalendarFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setHabitId(String? id) => state = id;
}

final habitsTabIndexProvider =
    NotifierProvider<HabitsTabIndexNotifier, int>(HabitsTabIndexNotifier.new);

class HabitsTabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) => state = index;
}

final highlightedOccurrenceIdProvider =
    NotifierProvider<HighlightedOccurrenceNotifier, String?>(
  HighlightedOccurrenceNotifier.new,
);

class HighlightedOccurrenceNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setId(String? id) => state = id;
}

class HabitActions {
  HabitActions(this._ref);

  final Ref _ref;

  Future<void> createHabit({
    required String name,
    required HabitKind kind,
    HabitSchedule? schedule,
    QuantityWindowGoal? quantityGoal,
    int? reminderTimeMinutes,
    int? colorValue,
    String iconName = 'fitness_center',
    DateTime? adhocDueAt,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Habit name cannot be empty');
    }
    if (kind == HabitKind.quantity && quantityGoal == null) {
      throw ArgumentError('Quantity goal is required');
    }

    final habit = Habit(
      id: _uuid.v4(),
      name: trimmed,
      createdAt: DateTime.now(),
      kind: kind,
      schedule: kind == HabitKind.repeatable
          ? (schedule ?? HabitSchedule.daily())
          : null,
      quantityGoal: kind == HabitKind.quantity ? quantityGoal : null,
      reminderTimeMinutes: reminderTimeMinutes,
      colorValue: colorValue,
      iconName: iconName,
    );

    final repo = _ref.read(habitRepositoryProvider);
    await repo.addHabit(habit);

    if (kind == HabitKind.adhoc) {
      final due = adhocDueAt ?? DateTime.now();
      await repo.upsertOccurrence(
        HabitOccurrence(
          id: _uuid.v4(),
          habitId: habit.id,
          dueAt: due,
          status: OccurrenceStatus.pending,
        ),
      );
    } else if (kind == HabitKind.repeatable) {
      await repo.syncHabitSchedule(habit);
    }

    await _rescheduleNotifications(habit);
  }

  Future<void> updateHabit(Habit habit) async {
    final repo = _ref.read(habitRepositoryProvider);
    await repo.updateHabit(habit);
    await repo.syncHabitSchedule(habit);
    await _rescheduleNotifications(habit);
  }

  Future<void> archiveHabit(String id) async {
    final repo = _ref.read(habitRepositoryProvider);
    await repo.archiveHabit(id);
    await _ref.read(habitNotificationSchedulerProvider).cancelHabit(id);
  }

  Future<void> deleteHabit(String id) async {
    await _ref.read(habitNotificationSchedulerProvider).cancelHabit(id);
    await _ref.read(habitRepositoryProvider).deleteHabit(id);
  }

  Future<void> completeOccurrence(String occurrenceId) async {
    final repo = _ref.read(habitRepositoryProvider);
    final occ = await repo.getOccurrence(occurrenceId);
    if (occ == null) return;
    final habit = await repo.getHabit(occ.habitId);
    if (habit != null) {
      ensureRetroDateAllowed(habit.createdAt, occ.dueAt);
    }
    await repo.setOccurrenceStatus(
      occurrenceId: occurrenceId,
      status: OccurrenceStatus.completed,
    );
    if (habit != null) {
      await repo.syncHabitSchedule(habit);
      await _rescheduleNotifications(habit);
    }
    _invalidateHabitDerived(occ.habitId);
  }

  Future<void> skipOccurrence(String occurrenceId) async {
    final repo = _ref.read(habitRepositoryProvider);
    await repo.setOccurrenceStatus(
      occurrenceId: occurrenceId,
      status: OccurrenceStatus.skipped,
    );
    final occ = await repo.getOccurrence(occurrenceId);
    if (occ != null) {
      final habit = await repo.getHabit(occ.habitId);
      if (habit != null) await _rescheduleNotifications(habit);
      _invalidateHabitDerived(occ.habitId);
    }
  }

  Future<void> uncompleteOccurrence(String occurrenceId) async {
    final repo = _ref.read(habitRepositoryProvider);
    final occ = await repo.getOccurrence(occurrenceId);
    if (occ == null) return;
    final today = dateOnly(DateTime.now());
    // Past undos become missed (not pending) so streak gaps stay consistent.
    final status = dateOnly(occ.dueAt).isBefore(today)
        ? OccurrenceStatus.missed
        : OccurrenceStatus.pending;
    await repo.setOccurrenceStatus(
      occurrenceId: occurrenceId,
      status: status,
      completedAt: null,
    );
    _invalidateHabitDerived(occ.habitId);
  }

  Future<void> logQuantity({
    required String habitId,
    num quantity = 1,
    DateTime? at,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError('Quantity must be positive');
    }
    final repo = _ref.read(habitRepositoryProvider);
    final habit = await repo.getHabit(habitId);
    final loggedAt = at ?? DateTime.now();
    if (habit != null) {
      ensureRetroDateAllowed(habit.createdAt, loggedAt);
    }
    await repo.addQuantityLog(
      HabitQuantityLog(
        id: _uuid.v4(),
        habitId: habitId,
        loggedAt: loggedAt,
        quantity: quantity,
      ),
    );
    _invalidateHabitDerived(habitId);
  }

  Future<void> deleteQuantityLog(String logId) async {
    final repo = _ref.read(habitRepositoryProvider);
    String? habitId;
    final habits = await repo.getHabits(includeArchived: true);
    for (final h in habits) {
      if (!h.isQuantityGoal) continue;
      final logs = await repo.getQuantityLogs(h.id);
      if (logs.any((l) => l.id == logId)) {
        habitId = h.id;
        break;
      }
    }
    await repo.deleteQuantityLog(logId);
    if (habitId != null) {
      _invalidateHabitDerived(habitId);
    } else {
      _ref.invalidate(allQuantityLogsProvider);
    }
  }

  void _invalidateHabitDerived(String habitId) {
    _ref.invalidate(habitOccurrencesProvider(habitId));
    _ref.invalidate(habitQuantityLogsProvider(habitId));
    _ref.invalidate(habitStreakProvider(habitId));
    _ref.invalidate(habitQuantityProgressProvider(habitId));
    _ref.invalidate(allOccurrencesProvider);
    _ref.invalidate(allQuantityLogsProvider);
  }

  Future<void> syncAllHabits() async {
    final repo = _ref.read(habitRepositoryProvider);
    // Clean legacy same-day duplicates across all habits once up front.
    await repo.dedupeOccurrenceDays();
    final habits = await repo.getHabits();
    for (final habit in habits) {
      await repo.syncHabitSchedule(habit);
      await _rescheduleNotifications(habit);
    }
  }

  Future<void> _rescheduleNotifications(Habit habit) async {
    if (habit.kind == HabitKind.quantity) return;
    final repo = _ref.read(habitRepositoryProvider);
    final from = DateTime.now();
    final upcoming = await repo.getOccurrences(
      habit.id,
      from: from,
      to: from.add(const Duration(days: 60)),
    );
    await _ref.read(habitNotificationSchedulerProvider).rescheduleHabit(
          habit: habit,
          upcomingPending: upcoming
              .where((o) => o.status == OccurrenceStatus.pending)
              .toList(),
        );
  }
}

final habitActionsProvider = Provider<HabitActions>((ref) => HabitActions(ref));

IconData habitIconData(String name) {
  return switch (name) {
    'fitness_center' => Icons.fitness_center,
    'menu_book' => Icons.menu_book,
    'self_improvement' => Icons.self_improvement,
    'water_drop' => Icons.water_drop,
    'bedtime' => Icons.bedtime,
    'directions_run' => Icons.directions_run,
    'psychology' => Icons.psychology,
    'restaurant' => Icons.restaurant,
    _ => Icons.star,
  };
}

const habitIconOptions = [
  'fitness_center',
  'menu_book',
  'self_improvement',
  'water_drop',
  'bedtime',
  'directions_run',
  'psychology',
  'restaurant',
];

const habitColorOptions = [
  0xFF1B6B4A,
  0xFF1565C0,
  0xFF6A1B9A,
  0xFFC62828,
  0xFFEF6C00,
  0xFF00838F,
];
