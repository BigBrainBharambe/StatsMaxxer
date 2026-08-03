import 'package:flutter_test/flutter_test.dart';
import 'package:stat_maxxer/features/habits/domain/habit.dart';
import 'package:stat_maxxer/features/habits/domain/occurrence_engine.dart';

void main() {
  const engine = OccurrenceEngine();

  test('every N days', () {
    final dates = engine.dueDatesInRange(
      schedule: const HabitSchedule(interval: 2, unit: ScheduleUnit.day),
      from: DateTime(2026, 7, 1),
      to: DateTime(2026, 7, 10),
      anchor: DateTime(2026, 7, 1),
    );
    expect(
      dates,
      [
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 3),
        DateTime(2026, 7, 5),
        DateTime(2026, 7, 7),
        DateTime(2026, 7, 9),
      ],
    );
  });

  test('weekly on Mon and Thu', () {
    final dates = engine.dueDatesInRange(
      schedule: const HabitSchedule(
        interval: 1,
        unit: ScheduleUnit.week,
        weekdays: [1, 4],
      ),
      from: DateTime(2026, 7, 13), // Monday
      to: DateTime(2026, 7, 20),
      anchor: DateTime(2026, 7, 13),
    );
    expect(dates, [
      DateTime(2026, 7, 13),
      DateTime(2026, 7, 16),
    ]);
  });

  test('every 2 weeks on Monday', () {
    final dates = engine.dueDatesInRange(
      schedule: const HabitSchedule(
        interval: 2,
        unit: ScheduleUnit.week,
        weekdays: [1],
      ),
      from: DateTime(2026, 7, 6),
      to: DateTime(2026, 8, 4),
      anchor: DateTime(2026, 7, 6),
    );
    expect(dates, [
      DateTime(2026, 7, 6),
      DateTime(2026, 7, 20),
      DateTime(2026, 8, 3),
    ]);
  });

  test('monthly on day 1 and 15', () {
    final dates = engine.dueDatesInRange(
      schedule: const HabitSchedule(
        interval: 1,
        unit: ScheduleUnit.month,
        monthDays: [1, 15],
      ),
      from: DateTime(2026, 7, 1),
      to: DateTime(2026, 9, 1),
      anchor: DateTime(2026, 7, 1),
    );
    expect(dates, [
      DateTime(2026, 7, 1),
      DateTime(2026, 7, 15),
      DateTime(2026, 8, 1),
      DateTime(2026, 8, 15),
    ]);
  });

  test('yearly on June 15', () {
    final dates = engine.dueDatesInRange(
      schedule: const HabitSchedule(
        interval: 1,
        unit: ScheduleUnit.year,
        month: 6,
        day: 15,
      ),
      from: DateTime(2025, 1, 1),
      to: DateTime(2028, 1, 1),
      anchor: DateTime(2025, 6, 15),
    );
    expect(dates, [
      DateTime(2025, 6, 15),
      DateTime(2026, 6, 15),
      DateTime(2027, 6, 15),
    ]);
  });
}
