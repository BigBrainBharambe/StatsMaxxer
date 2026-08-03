import 'package:flutter_test/flutter_test.dart';
import 'package:stat_maxxer/features/habits/domain/habit_occurrence.dart';
import 'package:stat_maxxer/features/habits/domain/occurrence_day_collapse.dart';

void main() {
  HabitOccurrence occ(
    String id,
    DateTime due, {
    OccurrenceStatus status = OccurrenceStatus.pending,
    String habitId = 'h1',
  }) {
    return HabitOccurrence(
      id: id,
      habitId: habitId,
      dueAt: due,
      status: status,
      completedAt: status == OccurrenceStatus.completed ? due : null,
    );
  }

  test('collapse prefers completed over missed same day', () {
    final collapsed = collapseOccurrencesByCalendarDay([
      occ('a', DateTime(2026, 7, 15), status: OccurrenceStatus.completed),
      occ('b', DateTime(2026, 7, 15, 9), status: OccurrenceStatus.missed),
    ]);
    expect(collapsed, hasLength(1));
    expect(collapsed.single.id, 'a');
    expect(collapsed.single.status, OccurrenceStatus.completed);
  });

  test('collapse prefers missed over pending same day', () {
    final collapsed = collapseOccurrencesByCalendarDay([
      occ('a', DateTime(2026, 7, 15), status: OccurrenceStatus.pending),
      occ('b', DateTime(2026, 7, 15, 9), status: OccurrenceStatus.missed),
    ]);
    expect(collapsed.single.id, 'b');
    expect(collapsed.single.status, OccurrenceStatus.missed);
  });

  test('duplicateOccurrenceLosers lists non-winners', () {
    final losers = duplicateOccurrenceLosers([
      occ('a', DateTime(2026, 7, 15), status: OccurrenceStatus.completed),
      occ('b', DateTime(2026, 7, 15, 9), status: OccurrenceStatus.missed),
      occ('c', DateTime(2026, 7, 16), status: OccurrenceStatus.pending),
    ]);
    expect(losers.map((o) => o.id), ['b']);
  });

  test('collapseOccurrencesByHabitAndDay keeps separate habits', () {
    final collapsed = collapseOccurrencesByHabitAndDay([
      occ('a', DateTime(2026, 7, 15), habitId: 'h1'),
      occ('b', DateTime(2026, 7, 15, 9), habitId: 'h2'),
    ]);
    expect(collapsed, hasLength(2));
  });
}
