import 'habit.dart';
import 'habit_occurrence.dart';
import 'habit_quantity_log.dart';

abstract class HabitRepository {
  Stream<List<Habit>> watchHabits({bool includeArchived = false});
  Future<List<Habit>> getHabits({bool includeArchived = false});
  Future<Habit?> getHabit(String id);
  Future<void> addHabit(Habit habit);
  Future<void> updateHabit(Habit habit);
  Future<void> archiveHabit(String id, {bool archived = true});
  Future<void> deleteHabit(String id);

  Stream<List<HabitOccurrence>> watchOccurrences(String habitId);
  Stream<List<HabitOccurrence>> watchAllOccurrences({
    DateTime? from,
    DateTime? to,
  });
  Future<List<HabitOccurrence>> getOccurrences(
    String habitId, {
    DateTime? from,
    DateTime? to,
  });
  Future<List<HabitOccurrence>> getOccurrencesInRange({
    required DateTime from,
    required DateTime to,
    String? habitId,
  });
  Future<HabitOccurrence?> getOccurrence(String id);
  Future<void> upsertOccurrence(HabitOccurrence occurrence);
  Future<void> upsertOccurrences(List<HabitOccurrence> occurrences);
  Future<void> setOccurrenceStatus({
    required String occurrenceId,
    required OccurrenceStatus status,
    DateTime? completedAt,
  });

  /// Deletes same-calendar-day duplicate dues, keeping the best status.
  /// When [habitId] is null, cleans all habits. Returns rows deleted.
  Future<int> dedupeOccurrenceDays({String? habitId});

  /// Materialize upcoming due dates and mark past pending as missed.
  Future<void> syncHabitSchedule(
    Habit habit, {
    DateTime? now,
    int horizonDays = 60,
  });

  Stream<List<HabitQuantityLog>> watchQuantityLogs(String habitId);
  Stream<List<HabitQuantityLog>> watchAllQuantityLogs({
    DateTime? from,
    DateTime? to,
  });
  Future<List<HabitQuantityLog>> getQuantityLogs(
    String habitId, {
    DateTime? from,
    DateTime? to,
  });
  Future<void> addQuantityLog(HabitQuantityLog log);
  Future<void> deleteQuantityLog(String id);
}
