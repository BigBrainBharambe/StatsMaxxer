import 'package:flutter_test/flutter_test.dart';
import 'package:stat_maxxer/features/habits/data/in_memory_habit_repository.dart';
import 'package:stat_maxxer/features/habits/domain/habit.dart';
import 'package:stat_maxxer/features/habits/domain/habit_occurrence.dart';
import 'package:stat_maxxer/features/habits/domain/habit_quantity_log.dart';
import 'package:stat_maxxer/features/habits/domain/quantity_window_goal.dart';
import 'package:stat_maxxer/features/habits/domain/streak_calculator.dart';

void main() {
  late InMemoryHabitRepository repo;

  setUp(() {
    repo = InMemoryHabitRepository();
  });

  tearDown(() {
    repo.dispose();
  });

  test('adds and lists habits', () async {
    await repo.addHabit(
      Habit(
        id: '1',
        name: 'Read',
        createdAt: DateTime(2026, 1, 1),
        schedule: HabitSchedule.daily(),
      ),
    );
    final habits = await repo.getHabits();
    expect(habits, hasLength(1));
    expect(habits.first.name, 'Read');
  });

  test('sync materializes daily occurrences', () async {
    final habit = Habit(
      id: '1',
      name: 'Read',
      createdAt: DateTime(2026, 7, 1),
      schedule: HabitSchedule.daily(),
    );
    await repo.addHabit(habit);
    await repo.syncHabitSchedule(
      habit,
      now: DateTime(2026, 7, 18),
      horizonDays: 5,
    );
    final occ = await repo.getOccurrences(
      '1',
      from: DateTime(2026, 7, 18),
      to: DateTime(2026, 7, 23),
    );
    expect(occ.length, 5);
    expect(occ.every((o) => o.status == OccurrenceStatus.pending), isTrue);
  });

  test('setOccurrenceStatus completes and upserts', () async {
    await repo.addHabit(
      Habit(id: '1', name: 'Read', createdAt: DateTime(2026, 1, 1)),
    );
    await repo.upsertOccurrence(
      HabitOccurrence(
        id: 'o1',
        habitId: '1',
        dueAt: DateTime(2026, 7, 10),
        status: OccurrenceStatus.pending,
      ),
    );
    await repo.setOccurrenceStatus(
      occurrenceId: 'o1',
      status: OccurrenceStatus.completed,
    );
    final o = await repo.getOccurrence('o1');
    expect(o!.status, OccurrenceStatus.completed);
    expect(o.completedAt, isNotNull);
  });

  test('deletes habit and its occurrences', () async {
    await repo.addHabit(
      Habit(id: '1', name: 'Read', createdAt: DateTime(2026, 1, 1)),
    );
    await repo.upsertOccurrence(
      HabitOccurrence(
        id: 'o1',
        habitId: '1',
        dueAt: DateTime(2026, 7, 10),
        status: OccurrenceStatus.completed,
      ),
    );
    await repo.deleteHabit('1');
    expect(await repo.getHabits(), isEmpty);
    expect(await repo.getOccurrences('1'), isEmpty);
  });

  test('marks past pending as missed on sync', () async {
    final habit = Habit(
      id: '1',
      name: 'Read',
      createdAt: DateTime(2026, 7, 1),
      schedule: HabitSchedule.daily(),
    );
    await repo.addHabit(habit);
    await repo.upsertOccurrence(
      HabitOccurrence(
        id: 'old',
        habitId: '1',
        dueAt: DateTime(2026, 7, 10),
        status: OccurrenceStatus.pending,
      ),
    );
    await repo.syncHabitSchedule(habit, now: DateTime(2026, 7, 18));
    final old = await repo.getOccurrence('old');
    expect(old!.status, OccurrenceStatus.missed);
  });

  test('upsertOccurrences does not add second row for same calendar day', () async {
    final habit = Habit(
      id: '1',
      name: 'Read',
      createdAt: DateTime(2026, 7, 1),
      schedule: HabitSchedule.daily(),
    );
    await repo.addHabit(habit);
    await repo.upsertOccurrence(
      HabitOccurrence(
        id: 'midnight',
        habitId: '1',
        dueAt: DateTime(2026, 7, 15),
        status: OccurrenceStatus.completed,
      ),
    );
    await repo.upsertOccurrences([
      HabitOccurrence(
        id: 'reminder',
        habitId: '1',
        dueAt: DateTime(2026, 7, 15, 9),
        status: OccurrenceStatus.missed,
      ),
    ]);
    final all = await repo.getOccurrences('1');
    expect(all, hasLength(1));
    expect(all.single.id, 'midnight');
    expect(all.single.status, OccurrenceStatus.completed);
  });

  test('four retro completes after sync yield streak 4', () async {
    const streakCalc = StreakCalculator();
    final habit = Habit(
      id: '1',
      name: 'Read',
      createdAt: DateTime(2026, 7, 18),
      schedule: HabitSchedule.daily(),
    );
    await repo.addHabit(habit);
    await repo.syncHabitSchedule(
      habit,
      now: DateTime(2026, 7, 18),
      horizonDays: 2,
    );
    final all = await repo.getOccurrences('1');
    final byDay = {
      for (final o in all) DateTime(o.dueAt.year, o.dueAt.month, o.dueAt.day): o,
    };
    for (final day in [
      DateTime(2026, 7, 15),
      DateTime(2026, 7, 16),
      DateTime(2026, 7, 17),
      DateTime(2026, 7, 18),
    ]) {
      final o = byDay[day]!;
      await repo.setOccurrenceStatus(
        occurrenceId: o.id,
        status: OccurrenceStatus.completed,
      );
    }
    final after = await repo.getOccurrences('1');
    final result = streakCalc.calculate(after, today: DateTime(2026, 7, 18));
    expect(result.current, 4);
    expect(result.best, 4);
  });

  test('sync backfills dues in retro window before today as missed', () async {
    final habit = Habit(
      id: '1',
      name: 'Read',
      createdAt: DateTime(2026, 7, 18),
      schedule: HabitSchedule.daily(),
    );
    await repo.addHabit(habit);
    await repo.syncHabitSchedule(
      habit,
      now: DateTime(2026, 7, 18),
      horizonDays: 2,
    );
    final past = await repo.getOccurrences(
      '1',
      from: DateTime(2026, 7, 11),
      to: DateTime(2026, 7, 18),
    );
    expect(past, isNotEmpty);
    expect(past.every((o) => o.status == OccurrenceStatus.missed), isTrue);

    final todayOnward = await repo.getOccurrences(
      '1',
      from: DateTime(2026, 7, 18),
      to: DateTime(2026, 7, 20),
    );
    expect(todayOnward, isNotEmpty);
    expect(
      todayOnward.every((o) => o.status == OccurrenceStatus.pending),
      isTrue,
    );
  });

  test('quantity logs cascade on delete and skip schedule sync', () async {
    final habit = Habit(
      id: 'q1',
      name: 'Water',
      createdAt: DateTime(2026, 7, 1),
      kind: HabitKind.quantity,
      quantityGoal: const QuantityWindowGoal(
        comparator: QuantityComparator.gt,
        target: 3,
        unitLabel: 'glasses',
        windowSize: 24,
        windowUnit: QuantityWindowUnit.hour,
      ),
    );
    await repo.addHabit(habit);
    await repo.addQuantityLog(
      HabitQuantityLog(
        id: 'l1',
        habitId: 'q1',
        loggedAt: DateTime(2026, 7, 18, 10),
        quantity: 1,
      ),
    );
    await repo.syncHabitSchedule(habit, now: DateTime(2026, 7, 18));
    expect(await repo.getOccurrences('q1'), isEmpty);

    final logs = await repo.getQuantityLogs('q1');
    expect(logs, hasLength(1));
    expect(logs.first.quantity, 1);

    await repo.deleteHabit('q1');
    expect(await repo.getQuantityLogs('q1'), isEmpty);
  });

  test('dedupeOccurrenceDays keeps completed winner and deletes loser', () async {
    await repo.addHabit(
      Habit(id: '1', name: 'Read', createdAt: DateTime(2026, 7, 1)),
    );
    await repo.upsertOccurrence(
      HabitOccurrence(
        id: 'o-mid',
        habitId: '1',
        dueAt: DateTime(2026, 7, 15),
        status: OccurrenceStatus.completed,
        completedAt: DateTime(2026, 7, 15),
      ),
    );
    await repo.upsertOccurrence(
      HabitOccurrence(
        id: 'o-rem',
        habitId: '1',
        dueAt: DateTime(2026, 7, 15, 9),
        status: OccurrenceStatus.missed,
      ),
    );
    expect(await repo.getOccurrences('1'), hasLength(2));

    final deleted = await repo.dedupeOccurrenceDays(habitId: '1');
    expect(deleted, 1);
    final remaining = await repo.getOccurrences('1');
    expect(remaining, hasLength(1));
    expect(remaining.single.id, 'o-mid');
    expect(remaining.single.status, OccurrenceStatus.completed);
  });

  test('syncHabitSchedule dedupes legacy same-day rows', () async {
    final habit = Habit(
      id: '1',
      name: 'Read',
      createdAt: DateTime(2026, 7, 1),
      schedule: HabitSchedule.daily(),
      reminderTimeMinutes: 9 * 60,
    );
    await repo.addHabit(habit);
    await repo.upsertOccurrence(
      HabitOccurrence(
        id: 'o-mid',
        habitId: '1',
        dueAt: DateTime(2026, 7, 15),
        status: OccurrenceStatus.completed,
        completedAt: DateTime(2026, 7, 15),
      ),
    );
    await repo.upsertOccurrence(
      HabitOccurrence(
        id: 'o-rem',
        habitId: '1',
        dueAt: DateTime(2026, 7, 15, 9),
        status: OccurrenceStatus.missed,
      ),
    );

    await repo.syncHabitSchedule(habit, now: DateTime(2026, 7, 18));
    final day = await repo.getOccurrences(
      '1',
      from: DateTime(2026, 7, 15),
      to: DateTime(2026, 7, 16),
    );
    expect(day, hasLength(1));
    expect(day.single.status, OccurrenceStatus.completed);
  });
}
