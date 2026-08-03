import 'package:flutter_test/flutter_test.dart';
import 'package:stat_maxxer/features/habits/domain/habit_quantity_log.dart';
import 'package:stat_maxxer/features/habits/domain/quantity_window_goal.dart';
import 'package:stat_maxxer/features/habits/domain/quantity_window_streak_calculator.dart';

void main() {
  const calculator = QuantityWindowStreakCalculator();

  HabitQuantityLog log(DateTime at, {num qty = 1, String id = ''}) {
    return HabitQuantityLog(
      id: id.isEmpty ? at.toIso8601String() : id,
      habitId: 'h1',
      loggedAt: at,
      quantity: qty,
    );
  }

  group('QuantityWindowGoal', () {
    test('encodes and decodes', () {
      const goal = QuantityWindowGoal(
        comparator: QuantityComparator.gte,
        target: 3,
        unitLabel: 'glasses',
        windowSize: 24,
        windowUnit: QuantityWindowUnit.hour,
      );
      final roundTrip = QuantityWindowGoal.tryDecode(goal.encode());
      expect(roundTrip?.comparator, QuantityComparator.gte);
      expect(roundTrip?.target, 3);
      expect(roundTrip?.unitLabel, 'glasses');
      expect(roundTrip?.windowSize, 24);
      expect(roundTrip?.windowUnit, QuantityWindowUnit.hour);
      expect(goal.summary, '≥3 glasses / 24 hours');
    });

    test('evaluate comparators', () {
      expect(QuantityComparator.gt.evaluate(4, 3), isTrue);
      expect(QuantityComparator.gt.evaluate(3, 3), isFalse);
      expect(QuantityComparator.gte.evaluate(3, 3), isTrue);
      expect(QuantityComparator.lt.evaluate(2, 3), isTrue);
      expect(QuantityComparator.lte.evaluate(3, 3), isTrue);
    });
  });

  group('progress — calendar day window', () {
    const goal = QuantityWindowGoal(
      comparator: QuantityComparator.gt,
      target: 3,
      unitLabel: 'glasses',
      windowSize: 1,
      windowUnit: QuantityWindowUnit.day,
    );

    test('counts logs on today only', () {
      final now = DateTime(2026, 7, 18, 15);
      final progress = calculator.progress(
        goal: goal,
        logs: [
          log(DateTime(2026, 7, 17, 10)),
          log(DateTime(2026, 7, 18, 8)),
          log(DateTime(2026, 7, 18, 12), qty: 2),
        ],
        now: now,
      );
      expect(progress.currentQuantity, 3);
      expect(progress.met, isFalse); // >3 needed
      expect(progress.label, contains('3/3'));
    });

    test('met when quantity exceeds target', () {
      final now = DateTime(2026, 7, 18, 15);
      final progress = calculator.progress(
        goal: goal,
        logs: [
          log(DateTime(2026, 7, 18, 8)),
          log(DateTime(2026, 7, 18, 9)),
          log(DateTime(2026, 7, 18, 10)),
          log(DateTime(2026, 7, 18, 11)),
        ],
        now: now,
      );
      expect(progress.currentQuantity, 4);
      expect(progress.met, isTrue);
    });
  });

  group('progress — rolling hours', () {
    const goal = QuantityWindowGoal(
      comparator: QuantityComparator.gt,
      target: 3,
      unitLabel: 'glasses',
      windowSize: 24,
      windowUnit: QuantityWindowUnit.hour,
    );

    test('includes logs within last 24h and excludes older', () {
      final now = DateTime(2026, 7, 18, 12);
      final progress = calculator.progress(
        goal: goal,
        logs: [
          log(DateTime(2026, 7, 17, 11)), // 25h ago — out
          log(DateTime(2026, 7, 17, 13)), // 23h ago — in
          log(DateTime(2026, 7, 18, 10), qty: 2),
        ],
        now: now,
      );
      expect(progress.currentQuantity, 3);
      expect(progress.met, isFalse);
    });

    test('exactly at window boundary is included', () {
      final now = DateTime(2026, 7, 18, 12);
      final progress = calculator.progress(
        goal: goal,
        logs: [log(DateTime(2026, 7, 17, 12), qty: 4)],
        now: now,
      );
      expect(progress.currentQuantity, 4);
      expect(progress.met, isTrue);
    });
  });

  group('progress — multi-day calendar window', () {
    const goal = QuantityWindowGoal(
      comparator: QuantityComparator.gte,
      target: 3,
      unitLabel: 'workouts',
      windowSize: 7,
      windowUnit: QuantityWindowUnit.day,
    );

    test('sums across last 7 calendar days', () {
      final now = DateTime(2026, 7, 18, 20);
      final progress = calculator.progress(
        goal: goal,
        logs: [
          log(DateTime(2026, 7, 11)), // 8 days back endDay-7 = Jul 12; out
          log(DateTime(2026, 7, 12)),
          log(DateTime(2026, 7, 15)),
          log(DateTime(2026, 7, 18)),
        ],
        now: now,
      );
      expect(progress.currentQuantity, 3);
      expect(progress.met, isTrue);
    });
  });

  group('streaks', () {
    const dailyGoal = QuantityWindowGoal(
      comparator: QuantityComparator.gte,
      target: 2,
      unitLabel: 'glasses',
      windowSize: 1,
      windowUnit: QuantityWindowUnit.day,
    );

    test('counts consecutive success days', () {
      final now = DateTime(2026, 7, 18, 20);
      final result = calculator.calculate(
        goal: dailyGoal,
        logs: [
          log(DateTime(2026, 7, 16, 9)),
          log(DateTime(2026, 7, 16, 18)),
          log(DateTime(2026, 7, 17, 9)),
          log(DateTime(2026, 7, 17, 18)),
          log(DateTime(2026, 7, 18, 9)),
          log(DateTime(2026, 7, 18, 18)),
        ],
        now: now,
        since: DateTime(2026, 7, 16),
      );
      expect(result.current, 3);
      expect(result.best, 3);
    });

    test('four consecutive success days yield streak 4', () {
      final now = DateTime(2026, 7, 18, 20);
      final result = calculator.calculate(
        goal: dailyGoal,
        logs: [
          for (var d = 15; d <= 18; d++) ...[
            log(DateTime(2026, 7, d, 9)),
            log(DateTime(2026, 7, d, 18)),
          ],
        ],
        now: now,
        since: DateTime(2026, 7, 15),
      );
      expect(result.current, 4);
      expect(result.best, 4);
    });

    test('missed day breaks current streak but preserves best', () {
      final now = DateTime(2026, 7, 18, 20);
      final result = calculator.calculate(
        goal: dailyGoal,
        logs: [
          log(DateTime(2026, 7, 14, 9)),
          log(DateTime(2026, 7, 14, 18)),
          log(DateTime(2026, 7, 15, 9)),
          log(DateTime(2026, 7, 15, 18)),
          // 16 missed
          log(DateTime(2026, 7, 17, 9)),
          log(DateTime(2026, 7, 17, 18)),
          log(DateTime(2026, 7, 18, 9)),
          log(DateTime(2026, 7, 18, 18)),
        ],
        now: now,
        since: DateTime(2026, 7, 14),
      );
      expect(result.current, 2);
      expect(result.best, 2);
    });

    test('incomplete today does not break streak ending yesterday', () {
      final now = DateTime(2026, 7, 18, 10);
      final result = calculator.calculate(
        goal: dailyGoal,
        logs: [
          log(DateTime(2026, 7, 16, 9)),
          log(DateTime(2026, 7, 16, 18)),
          log(DateTime(2026, 7, 17, 9)),
          log(DateTime(2026, 7, 17, 18)),
          log(DateTime(2026, 7, 18, 9)), // only 1 today
        ],
        now: now,
        since: DateTime(2026, 7, 16),
      );
      expect(result.current, 2);
      expect(result.best, 2);
    });

    test('hour window success days for rolling 24h', () {
      const hourGoal = QuantityWindowGoal(
        comparator: QuantityComparator.gt,
        target: 3,
        unitLabel: 'glasses',
        windowSize: 24,
        windowUnit: QuantityWindowUnit.hour,
      );
      final now = DateTime(2026, 7, 18, 20);
      // On Jul 17 end-of-day: 4 logs in prior 24h → success
      // On Jul 18 now: still have logs in window → success
      final result = calculator.calculate(
        goal: hourGoal,
        logs: [
          log(DateTime(2026, 7, 17, 10)),
          log(DateTime(2026, 7, 17, 12)),
          log(DateTime(2026, 7, 17, 14)),
          log(DateTime(2026, 7, 17, 16)),
          log(DateTime(2026, 7, 18, 18)),
        ],
        now: now,
        since: DateTime(2026, 7, 17),
      );
      expect(result.current, greaterThanOrEqualTo(1));
      expect(result.best, greaterThanOrEqualTo(1));
    });

    test('retro logs before createdAt update streak when since is retro window', () {
      // Habit created Jul 18; logs on Jul 11–18 within C-7 window.
      final now = DateTime(2026, 7, 18, 20);
      final createdAt = DateTime(2026, 7, 18);
      final since = createdAt.subtract(const Duration(days: 7));

      final withoutRetroSince = calculator.calculate(
        goal: dailyGoal,
        logs: [
          for (var d = 11; d <= 18; d++) ...[
            log(DateTime(2026, 7, d, 9)),
            log(DateTime(2026, 7, d, 18)),
          ],
        ],
        now: now,
        since: createdAt,
      );
      expect(withoutRetroSince.current, 1);
      expect(withoutRetroSince.best, 1);

      final withRetroSince = calculator.calculate(
        goal: dailyGoal,
        logs: [
          for (var d = 11; d <= 18; d++) ...[
            log(DateTime(2026, 7, d, 9)),
            log(DateTime(2026, 7, d, 18)),
          ],
        ],
        now: now,
        since: since,
      );
      expect(withRetroSince.current, 8);
      expect(withRetroSince.best, 8);
    });

    test('retro filling a gap reconnects quantity streak', () {
      final now = DateTime(2026, 7, 18, 20);
      final before = calculator.calculate(
        goal: dailyGoal,
        logs: [
          log(DateTime(2026, 7, 14, 9)),
          log(DateTime(2026, 7, 14, 18)),
          // 15 missing
          log(DateTime(2026, 7, 16, 9)),
          log(DateTime(2026, 7, 16, 18)),
          log(DateTime(2026, 7, 17, 9)),
          log(DateTime(2026, 7, 17, 18)),
          log(DateTime(2026, 7, 18, 9)),
          log(DateTime(2026, 7, 18, 18)),
        ],
        now: now,
        since: DateTime(2026, 7, 14),
      );
      expect(before.current, 3);
      expect(before.best, 3);

      final after = calculator.calculate(
        goal: dailyGoal,
        logs: [
          log(DateTime(2026, 7, 14, 9)),
          log(DateTime(2026, 7, 14, 18)),
          log(DateTime(2026, 7, 15, 9)), // retro
          log(DateTime(2026, 7, 15, 18)),
          log(DateTime(2026, 7, 16, 9)),
          log(DateTime(2026, 7, 16, 18)),
          log(DateTime(2026, 7, 17, 9)),
          log(DateTime(2026, 7, 17, 18)),
          log(DateTime(2026, 7, 18, 9)),
          log(DateTime(2026, 7, 18, 18)),
        ],
        now: now,
        since: DateTime(2026, 7, 14),
      );
      expect(after.current, 5);
      expect(after.best, 5);
    });
  });

  group('quantityLoggedOnDay', () {
    test('sums only logs on that calendar day', () {
      final logs = [
        log(DateTime(2026, 7, 17, 10), qty: 1),
        log(DateTime(2026, 7, 18, 8), qty: 2),
        log(DateTime(2026, 7, 18, 20), qty: 1.5),
      ];
      expect(
        calculator.quantityLoggedOnDay(
          logs: logs,
          day: DateTime(2026, 7, 18),
        ),
        3.5,
      );
      expect(
        calculator.quantityLoggedOnDay(
          logs: logs,
          day: DateTime(2026, 7, 17),
        ),
        1,
      );
      expect(
        calculator.quantityLoggedOnDay(
          logs: logs,
          day: DateTime(2026, 7, 16),
        ),
        0,
      );
    });
  });
}
