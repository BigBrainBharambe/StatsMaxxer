import 'package:flutter_test/flutter_test.dart';
import 'package:stat_maxxer/features/habits/domain/habit_occurrence.dart';
import 'package:stat_maxxer/features/habits/domain/streak_calculator.dart';

void main() {
  const calculator = StreakCalculator();
  final today = DateTime(2026, 7, 18);

  HabitOccurrence occ(
    DateTime due, {
    OccurrenceStatus status = OccurrenceStatus.completed,
  }) {
    return HabitOccurrence(
      id: due.toIso8601String(),
      habitId: 'h1',
      dueAt: due,
      status: status,
      completedAt:
          status == OccurrenceStatus.completed ? due : null,
    );
  }

  group('StreakCalculator due-occurrence streaks', () {
    test('returns zero when empty', () {
      final result = calculator.calculate([], today: today);
      expect(result.current, 0);
      expect(result.best, 0);
    });

    test('counts consecutive completed dues', () {
      final result = calculator.calculate(
        [
          occ(DateTime(2026, 7, 14)),
          occ(DateTime(2026, 7, 16)),
          occ(DateTime(2026, 7, 18)),
        ],
        today: today,
      );
      expect(result.current, 3);
      expect(result.best, 3);
    });

    test('miss breaks current streak but preserves best', () {
      final result = calculator.calculate(
        [
          occ(DateTime(2026, 7, 10)),
          occ(DateTime(2026, 7, 12)),
          occ(DateTime(2026, 7, 14), status: OccurrenceStatus.missed),
          occ(DateTime(2026, 7, 16)),
          occ(DateTime(2026, 7, 18)),
        ],
        today: today,
      );
      expect(result.current, 2);
      expect(result.best, 2);
    });

    test('skip does not break streak', () {
      final result = calculator.calculate(
        [
          occ(DateTime(2026, 7, 14)),
          occ(DateTime(2026, 7, 16), status: OccurrenceStatus.skipped),
          occ(DateTime(2026, 7, 18)),
        ],
        today: today,
      );
      expect(result.current, 2);
      expect(result.best, 2);
    });

    test('pending today does not break streak ending previous due', () {
      final result = calculator.calculate(
        [
          occ(DateTime(2026, 7, 14)),
          occ(DateTime(2026, 7, 16)),
          occ(DateTime(2026, 7, 18), status: OccurrenceStatus.pending),
        ],
        today: today,
      );
      expect(result.current, 2);
      expect(result.best, 2);
    });

    test('retro completing a miss reconnects current and best streaks', () {
      final before = calculator.calculate(
        [
          occ(DateTime(2026, 7, 14)),
          occ(DateTime(2026, 7, 15), status: OccurrenceStatus.missed),
          occ(DateTime(2026, 7, 16)),
          occ(DateTime(2026, 7, 17)),
          occ(DateTime(2026, 7, 18), status: OccurrenceStatus.pending),
        ],
        today: today,
      );
      expect(before.current, 2);
      expect(before.best, 2);

      final after = calculator.calculate(
        [
          occ(DateTime(2026, 7, 14)),
          occ(DateTime(2026, 7, 15)), // retro completed
          occ(DateTime(2026, 7, 16)),
          occ(DateTime(2026, 7, 17)),
          occ(DateTime(2026, 7, 18), status: OccurrenceStatus.pending),
        ],
        today: today,
      );
      expect(after.current, 4);
      expect(after.best, 4);
    });

    test('retro undoing a middle day breaks current and shrinks best', () {
      final afterUndo = calculator.calculate(
        [
          occ(DateTime(2026, 7, 14)),
          occ(DateTime(2026, 7, 15), status: OccurrenceStatus.missed),
          occ(DateTime(2026, 7, 16)),
          occ(DateTime(2026, 7, 17)),
          occ(DateTime(2026, 7, 18)),
        ],
        today: today,
      );
      expect(afterUndo.current, 3);
      expect(afterUndo.best, 3);
    });

    test('four consecutive completed calendar days yield streak 4', () {
      final result = calculator.calculate(
        [
          occ(DateTime(2026, 7, 15)),
          occ(DateTime(2026, 7, 16)),
          occ(DateTime(2026, 7, 17)),
          occ(DateTime(2026, 7, 18)),
        ],
        today: today,
      );
      expect(result.current, 4);
      expect(result.best, 4);
    });

    test(
      'same-day missed duplicate does not break four completed days (regression)',
      () {
        // Midnight completes + later reminder-time misses on older days used to
        // stop the walk early → "4 done, streak 2".
        final result = calculator.calculate(
          [
            occ(DateTime(2026, 7, 15)),
            occ(DateTime(2026, 7, 15, 9), status: OccurrenceStatus.missed),
            occ(DateTime(2026, 7, 16)),
            occ(DateTime(2026, 7, 16, 9), status: OccurrenceStatus.missed),
            occ(DateTime(2026, 7, 17)),
            occ(DateTime(2026, 7, 18)),
          ],
          today: today,
        );
        expect(result.current, 4);
        expect(result.best, 4);
      },
    );

    test('pending today with four prior completes still yields streak 4', () {
      final result = calculator.calculate(
        [
          occ(DateTime(2026, 7, 14)),
          occ(DateTime(2026, 7, 15)),
          occ(DateTime(2026, 7, 16)),
          occ(DateTime(2026, 7, 17)),
          occ(DateTime(2026, 7, 18), status: OccurrenceStatus.pending),
        ],
        today: today,
      );
      expect(result.current, 4);
      expect(result.best, 4);
    });
  });
}
