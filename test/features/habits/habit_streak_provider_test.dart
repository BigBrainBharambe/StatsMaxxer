import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_maxxer/core/providers.dart';
import 'package:stat_maxxer/core/utils/date_utils.dart';
import 'package:stat_maxxer/features/habits/data/in_memory_habit_repository.dart';
import 'package:stat_maxxer/features/habits/domain/habit.dart';
import 'package:stat_maxxer/features/habits/domain/habit_occurrence.dart';
import 'package:stat_maxxer/features/habits/domain/quantity_window_goal.dart';
import 'package:stat_maxxer/features/habits/presentation/habits_providers.dart';

void main() {
  late InMemoryHabitRepository repo;
  late ProviderContainer container;
  late DateTime today;

  setUp(() {
    today = dateOnly(DateTime.now());
    repo = InMemoryHabitRepository();
    container = ProviderContainer(
      overrides: [
        habitRepositoryProvider.overrideWithValue(repo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    repo.dispose();
  });

  Future<({int current, int best})> readStreak(String habitId) async {
    // Ensure stream providers have emitted.
    container.listen(habitStreakProvider(habitId), (_, __) {});
    await pumpEventQueue();
    final async = container.read(habitStreakProvider(habitId));
    expect(async.hasValue, isTrue, reason: '$async');
    return async.requireValue;
  }

  test('completing today updates Current and Best from 0 to 1', () async {
    final habit = Habit(
      id: 'h1',
      name: 'Read',
      createdAt: today,
      kind: HabitKind.repeatable,
      schedule: HabitSchedule.daily(),
    );
    await repo.addHabit(habit);
    await repo.upsertOccurrence(
      HabitOccurrence(
        id: 'o-today',
        habitId: 'h1',
        dueAt: today,
        status: OccurrenceStatus.pending,
      ),
    );

    expect(await readStreak('h1'), (current: 0, best: 0));

    await container.read(habitActionsProvider).completeOccurrence('o-today');
    await pumpEventQueue();

    expect(await readStreak('h1'), (current: 1, best: 1));
  });

  test('completing yesterday then today grows Current and Best', () async {
    final yest = today.subtract(const Duration(days: 1));
    final habit = Habit(
      id: 'h1',
      name: 'Read',
      createdAt: yest,
      kind: HabitKind.repeatable,
      schedule: HabitSchedule.daily(),
    );
    await repo.addHabit(habit);
    await repo.upsertOccurrence(
      HabitOccurrence(
        id: 'o-yest',
        habitId: 'h1',
        dueAt: yest,
        status: OccurrenceStatus.missed,
      ),
    );
    await repo.upsertOccurrence(
      HabitOccurrence(
        id: 'o-today',
        habitId: 'h1',
        dueAt: today,
        status: OccurrenceStatus.pending,
      ),
    );

    expect(await readStreak('h1'), (current: 0, best: 0));

    await container.read(habitActionsProvider).completeOccurrence('o-yest');
    await pumpEventQueue();
    expect(await readStreak('h1'), (current: 1, best: 1));

    await container.read(habitActionsProvider).completeOccurrence('o-today');
    await pumpEventQueue();
    expect(await readStreak('h1'), (current: 2, best: 2));
  });

  test(
    'completing duplicate same-day row does not change streak when day already completed',
    () async {
      final habit = Habit(
        id: 'h1',
        name: 'Read',
        createdAt: today,
        kind: HabitKind.repeatable,
        schedule: HabitSchedule.daily(),
      );
      await repo.addHabit(habit);
      await repo.upsertOccurrence(
        HabitOccurrence(
          id: 'o-midnight',
          habitId: 'h1',
          dueAt: today,
          status: OccurrenceStatus.completed,
          completedAt: today,
        ),
      );
      // Exact dueAt differs → legacy duplicate same calendar day.
      await repo.upsertOccurrence(
        HabitOccurrence(
          id: 'o-reminder',
          habitId: 'h1',
          dueAt: DateTime(today.year, today.month, today.day, 9),
          status: OccurrenceStatus.missed,
        ),
      );

      expect(await readStreak('h1'), (current: 1, best: 1));

      // Provider list collapses to the completed winner only.
      container.listen(habitOccurrencesProvider('h1'), (_, __) {});
      await pumpEventQueue();
      final list =
          container.read(habitOccurrencesProvider('h1')).requireValue;
      expect(list, hasLength(1));
      expect(list.single.id, 'o-midnight');
      expect(list.single.status, OccurrenceStatus.completed);

      await container
          .read(habitActionsProvider)
          .completeOccurrence('o-reminder');
      await pumpEventQueue();

      // Day already counted; chips stay put (this is the "doesn't change" UX).
      expect(await readStreak('h1'), (current: 1, best: 1));
    },
  );

  test(
    'completing collapsed missed day (pending+missed dupes) updates Current/Best',
    () async {
      final habit = Habit(
        id: 'h1',
        name: 'Read',
        createdAt: today,
        kind: HabitKind.repeatable,
        schedule: HabitSchedule.daily(),
      );
      await repo.addHabit(habit);
      await repo.upsertOccurrence(
        HabitOccurrence(
          id: 'o-midnight',
          habitId: 'h1',
          dueAt: today,
          status: OccurrenceStatus.pending,
        ),
      );
      await repo.upsertOccurrence(
        HabitOccurrence(
          id: 'o-reminder',
          habitId: 'h1',
          dueAt: DateTime(today.year, today.month, today.day, 9),
          status: OccurrenceStatus.missed,
        ),
      );

      // Missed wins over pending → streak 0 until Done on the winner.
      expect(await readStreak('h1'), (current: 0, best: 0));

      container.listen(habitOccurrencesProvider('h1'), (_, __) {});
      await pumpEventQueue();
      final list =
          container.read(habitOccurrencesProvider('h1')).requireValue;
      expect(list.single.id, 'o-reminder');

      await container
          .read(habitActionsProvider)
          .completeOccurrence(list.single.id);
      await pumpEventQueue();

      expect(await readStreak('h1'), (current: 1, best: 1));
    },
  );

  test(
    'retro completing a missed gap reconnects Current and Best',
    () async {
      final d2 = today.subtract(const Duration(days: 2));
      final d1 = today.subtract(const Duration(days: 1));
      final habit = Habit(
        id: 'h1',
        name: 'Read',
        createdAt: d2,
        kind: HabitKind.repeatable,
        schedule: HabitSchedule.daily(),
      );
      await repo.addHabit(habit);
      await repo.upsertOccurrence(
        HabitOccurrence(
          id: 'o-2',
          habitId: 'h1',
          dueAt: d2,
          status: OccurrenceStatus.completed,
          completedAt: d2,
        ),
      );
      await repo.upsertOccurrence(
        HabitOccurrence(
          id: 'o-1',
          habitId: 'h1',
          dueAt: d1,
          status: OccurrenceStatus.missed,
        ),
      );
      await repo.upsertOccurrence(
        HabitOccurrence(
          id: 'o-today',
          habitId: 'h1',
          dueAt: today,
          status: OccurrenceStatus.completed,
          completedAt: today,
        ),
      );

      expect(await readStreak('h1'), (current: 1, best: 1));

      await container.read(habitActionsProvider).completeOccurrence('o-1');
      await pumpEventQueue();

      expect(await readStreak('h1'), (current: 3, best: 3));
    },
  );

  test(
    'quantity retro logs that meet the daily goal update Current and Best',
    () async {
      final d2 = today.subtract(const Duration(days: 2));
      final d1 = today.subtract(const Duration(days: 1));
      final habit = Habit(
        id: 'q1',
        name: 'Water',
        createdAt: d2,
        kind: HabitKind.quantity,
        quantityGoal: const QuantityWindowGoal(
          comparator: QuantityComparator.gte,
          target: 2,
          unitLabel: 'glasses',
          windowSize: 1,
          windowUnit: QuantityWindowUnit.day,
        ),
      );
      await repo.addHabit(habit);

      expect(await readStreak('q1'), (current: 0, best: 0));

      final actions = container.read(habitActionsProvider);
      await actions.logQuantity(
        habitId: 'q1',
        quantity: 2,
        at: DateTime(d2.year, d2.month, d2.day, 12),
      );
      await actions.logQuantity(
        habitId: 'q1',
        quantity: 2,
        at: DateTime(d1.year, d1.month, d1.day, 12),
      );
      await pumpEventQueue();

      // Today incomplete → Current counts through yesterday.
      expect(await readStreak('q1'), (current: 2, best: 2));

      await actions.logQuantity(
        habitId: 'q1',
        quantity: 2,
        at: DateTime(today.year, today.month, today.day, 12),
      );
      await pumpEventQueue();

      expect(await readStreak('q1'), (current: 3, best: 3));
    },
  );

  test(
    'quantity retro fill of a mid-streak gap reconnects Current and Best',
    () async {
      final d3 = today.subtract(const Duration(days: 3));
      final d2 = today.subtract(const Duration(days: 2));
      final d1 = today.subtract(const Duration(days: 1));
      final habit = Habit(
        id: 'q1',
        name: 'Water',
        createdAt: d3,
        kind: HabitKind.quantity,
        quantityGoal: const QuantityWindowGoal(
          comparator: QuantityComparator.gte,
          target: 1,
          unitLabel: 'glasses',
          windowSize: 1,
          windowUnit: QuantityWindowUnit.day,
        ),
      );
      await repo.addHabit(habit);
      final actions = container.read(habitActionsProvider);
      await actions.logQuantity(
        habitId: 'q1',
        at: DateTime(d3.year, d3.month, d3.day, 12),
      );
      // d2 gap
      await actions.logQuantity(
        habitId: 'q1',
        at: DateTime(d1.year, d1.month, d1.day, 12),
      );
      await actions.logQuantity(
        habitId: 'q1',
        at: DateTime(today.year, today.month, today.day, 12),
      );
      await pumpEventQueue();

      expect(await readStreak('q1'), (current: 2, best: 2));

      await actions.logQuantity(
        habitId: 'q1',
        at: DateTime(d2.year, d2.month, d2.day, 12),
      );
      await pumpEventQueue();

      expect(await readStreak('q1'), (current: 4, best: 4));
    },
  );
}
