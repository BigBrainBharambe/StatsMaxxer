import '../../../core/utils/date_utils.dart';
import 'habit_occurrence.dart';

/// Higher wins when collapsing same-calendar-day duplicate dues.
int occurrenceStatusRank(OccurrenceStatus status) => switch (status) {
      OccurrenceStatus.completed => 3,
      OccurrenceStatus.skipped => 2,
      OccurrenceStatus.missed => 1,
      OccurrenceStatus.pending => 0,
    };

/// Prefer higher status; on tie keep earlier [dueAt], then lower [id].
HabitOccurrence preferOccurrence(HabitOccurrence a, HabitOccurrence b) {
  final rankA = occurrenceStatusRank(a.status);
  final rankB = occurrenceStatusRank(b.status);
  if (rankA != rankB) return rankA > rankB ? a : b;
  final byDue = a.dueAt.compareTo(b.dueAt);
  if (byDue != 0) return byDue < 0 ? a : b;
  return a.id.compareTo(b.id) <= 0 ? a : b;
}

String occurrenceDayKey(String habitId, DateTime dueAt) {
  final d = dateOnly(dueAt);
  return '$habitId-${d.year}-${d.month}-${d.day}';
}

/// One occurrence per calendar day (single-habit list). Sorted ascending by day.
List<HabitOccurrence> collapseOccurrencesByCalendarDay(
  List<HabitOccurrence> list,
) {
  final byDay = <DateTime, HabitOccurrence>{};
  for (final o in list) {
    final day = dateOnly(o.dueAt);
    final existing = byDay[day];
    byDay[day] = existing == null ? o : preferOccurrence(existing, o);
  }
  final days = byDay.keys.toList()..sort();
  return [for (final d in days) byDay[d]!];
}

/// One occurrence per habit + calendar day (multi-habit lists).
List<HabitOccurrence> collapseOccurrencesByHabitAndDay(
  List<HabitOccurrence> list,
) {
  final byKey = <String, HabitOccurrence>{};
  for (final o in list) {
    final key = occurrenceDayKey(o.habitId, o.dueAt);
    final existing = byKey[key];
    byKey[key] = existing == null ? o : preferOccurrence(existing, o);
  }
  return byKey.values.toList()
    ..sort((a, b) {
      final byDue = a.dueAt.compareTo(b.dueAt);
      if (byDue != 0) return byDue;
      return a.habitId.compareTo(b.habitId);
    });
}

/// Losers to delete when multiple rows share a habit+calendar day.
List<HabitOccurrence> duplicateOccurrenceLosers(List<HabitOccurrence> list) {
  final groups = <String, List<HabitOccurrence>>{};
  for (final o in list) {
    groups.putIfAbsent(occurrenceDayKey(o.habitId, o.dueAt), () => []).add(o);
  }
  final losers = <HabitOccurrence>[];
  for (final group in groups.values) {
    if (group.length < 2) continue;
    var winner = group.first;
    for (final o in group.skip(1)) {
      winner = preferOccurrence(winner, o);
    }
    for (final o in group) {
      if (o.id != winner.id) losers.add(o);
    }
  }
  return losers;
}
