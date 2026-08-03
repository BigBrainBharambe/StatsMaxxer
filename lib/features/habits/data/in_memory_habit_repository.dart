import 'dart:async';

import '../../../core/utils/date_utils.dart';
import '../domain/habit.dart';
import '../domain/habit_occurrence.dart';
import '../domain/habit_quantity_log.dart';
import '../domain/habit_repository.dart';
import '../domain/habit_retro_rules.dart';
import '../domain/occurrence_day_collapse.dart';
import '../domain/occurrence_engine.dart';
import 'package:uuid/uuid.dart';

class InMemoryHabitRepository implements HabitRepository {
  InMemoryHabitRepository({OccurrenceEngine? engine, Uuid? uuid})
      : _engine = engine ?? const OccurrenceEngine(),
        _uuid = uuid ?? const Uuid();

  final OccurrenceEngine _engine;
  final Uuid _uuid;
  final Map<String, Habit> _habits = {};
  final Map<String, HabitOccurrence> _occurrences = {};
  final Map<String, HabitQuantityLog> _quantityLogs = {};
  final _habitsController = StreamController<List<Habit>>.broadcast();
  final _occControllers = <String, StreamController<List<HabitOccurrence>>>{};
  final _qtyControllers = <String, StreamController<List<HabitQuantityLog>>>{};
  final _allOccController =
      StreamController<List<HabitOccurrence>>.broadcast();
  final _allQtyController =
      StreamController<List<HabitQuantityLog>>.broadcast();

  void _emitHabits() {
    _habitsController.add(_filterHabits(true));
  }

  void _emitOccurrences(String habitId) {
    final controller = _occControllers.putIfAbsent(
      habitId,
      () => StreamController<List<HabitOccurrence>>.broadcast(),
    );
    controller.add(_sortedForHabit(habitId));
    _allOccController.add(_allSorted());
  }

  void _emitQuantityLogs(String habitId) {
    final controller = _qtyControllers.putIfAbsent(
      habitId,
      () => StreamController<List<HabitQuantityLog>>.broadcast(),
    );
    controller.add(_sortedQuantityLogs(habitId));
    _allQtyController.add(_allSortedQuantityLogs());
  }

  List<HabitQuantityLog> _allSortedQuantityLogs() {
    return _quantityLogs.values.toList()
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
  }

  List<HabitQuantityLog> _sortedQuantityLogs(String habitId) {
    return _quantityLogs.values.where((l) => l.habitId == habitId).toList()
      ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
  }

  List<Habit> _filterHabits(bool includeArchived) {
    return _habits.values
        .where((h) => includeArchived || !h.archived)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<HabitOccurrence> _sortedForHabit(String habitId) {
    return _occurrences.values.where((o) => o.habitId == habitId).toList()
      ..sort((a, b) => b.dueAt.compareTo(a.dueAt));
  }

  List<HabitOccurrence> _allSorted() {
    return _occurrences.values.toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
  }

  /// Unique per habit + calendar day (reminder time must not create duplicates).
  String _dayKey(String habitId, DateTime dueAt) {
    final d = dateOnly(dueAt);
    return '$habitId-${d.year}-${d.month}-${d.day}';
  }

  @override
  Stream<List<Habit>> watchHabits({bool includeArchived = false}) async* {
    yield _filterHabits(includeArchived);
    yield* _habitsController.stream
        .map((_) => _filterHabits(includeArchived));
  }

  @override
  Future<List<Habit>> getHabits({bool includeArchived = false}) async =>
      _filterHabits(includeArchived);

  @override
  Future<Habit?> getHabit(String id) async => _habits[id];

  @override
  Future<void> addHabit(Habit habit) async {
    _habits[habit.id] = habit;
    _emitHabits();
  }

  @override
  Future<void> updateHabit(Habit habit) async {
    _habits[habit.id] = habit;
    _emitHabits();
  }

  @override
  Future<void> archiveHabit(String id, {bool archived = true}) async {
    final h = _habits[id];
    if (h == null) return;
    _habits[id] = h.copyWith(archived: archived);
    _emitHabits();
  }

  @override
  Future<void> deleteHabit(String id) async {
    _habits.remove(id);
    _occurrences.removeWhere((_, o) => o.habitId == id);
    _quantityLogs.removeWhere((_, l) => l.habitId == id);
    _emitHabits();
    _emitOccurrences(id);
    _emitQuantityLogs(id);
  }

  @override
  Stream<List<HabitOccurrence>> watchOccurrences(String habitId) async* {
    yield _sortedForHabit(habitId);
    final controller = _occControllers.putIfAbsent(
      habitId,
      () => StreamController<List<HabitOccurrence>>.broadcast(),
    );
    yield* controller.stream;
  }

  @override
  Stream<List<HabitOccurrence>> watchAllOccurrences({
    DateTime? from,
    DateTime? to,
  }) async* {
    List<HabitOccurrence> filter(List<HabitOccurrence> all) {
      return all.where((o) {
        if (from != null && o.dueAt.isBefore(from)) return false;
        if (to != null && !o.dueAt.isBefore(to)) return false;
        return true;
      }).toList();
    }

    yield filter(_allSorted());
    yield* _allOccController.stream.map(filter);
  }

  @override
  Future<List<HabitOccurrence>> getOccurrences(
    String habitId, {
    DateTime? from,
    DateTime? to,
  }) async {
    return getOccurrencesInRange(
      from: from ?? DateTime(2000),
      to: to ?? DateTime(2100),
      habitId: habitId,
    );
  }

  @override
  Future<List<HabitOccurrence>> getOccurrencesInRange({
    required DateTime from,
    required DateTime to,
    String? habitId,
  }) async {
    return _occurrences.values.where((o) {
      if (habitId != null && o.habitId != habitId) return false;
      if (o.dueAt.isBefore(from)) return false;
      if (!o.dueAt.isBefore(to)) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
  }

  @override
  Future<HabitOccurrence?> getOccurrence(String id) async => _occurrences[id];

  @override
  Future<void> upsertOccurrence(HabitOccurrence occurrence) async {
    // Replace by same habit+due day key if exists
    HabitOccurrence? existing;
    for (final o in _occurrences.values) {
      if (o.habitId == occurrence.habitId &&
          o.dueAt.isAtSameMomentAs(occurrence.dueAt)) {
        existing = o;
        break;
      }
    }
    if (existing != null) {
      _occurrences.remove(existing.id);
      _occurrences[occurrence.id] = occurrence.copyWith(id: existing.id);
    } else {
      _occurrences[occurrence.id] = occurrence;
    }
    _emitOccurrences(occurrence.habitId);
  }

  @override
  Future<void> upsertOccurrences(List<HabitOccurrence> occurrences) async {
    for (final o in occurrences) {
      final key = _dayKey(o.habitId, o.dueAt);
      final exists = _occurrences.values.any(
        (e) => _dayKey(e.habitId, e.dueAt) == key,
      );
      if (!exists) {
        _occurrences[o.id] = o;
      }
    }
    final ids = occurrences.map((o) => o.habitId).toSet();
    for (final id in ids) {
      _emitOccurrences(id);
    }
  }

  @override
  Future<void> setOccurrenceStatus({
    required String occurrenceId,
    required OccurrenceStatus status,
    DateTime? completedAt,
  }) async {
    final existing = _occurrences[occurrenceId];
    if (existing == null) return;
    _occurrences[occurrenceId] = existing.copyWith(
      status: status,
      completedAt: status == OccurrenceStatus.completed
          ? (completedAt ?? DateTime.now())
          : null,
      clearCompletedAt: status != OccurrenceStatus.completed,
    );
    _emitOccurrences(existing.habitId);
  }

  @override
  Future<int> dedupeOccurrenceDays({String? habitId}) async {
    final source = habitId == null
        ? _occurrences.values.toList()
        : _occurrences.values.where((o) => o.habitId == habitId).toList();
    final losers = duplicateOccurrenceLosers(source);
    if (losers.isEmpty) return 0;
    final habitIds = <String>{};
    for (final o in losers) {
      _occurrences.remove(o.id);
      habitIds.add(o.habitId);
    }
    for (final id in habitIds) {
      _emitOccurrences(id);
    }
    return losers.length;
  }

  @override
  Future<void> syncHabitSchedule(
    Habit habit, {
    DateTime? now,
    int horizonDays = 60,
  }) async {
    final clock = now ?? DateTime.now();
    final today = dateOnly(clock);

    await dedupeOccurrenceDays(habitId: habit.id);

    for (final o in _occurrences.values
        .where(
          (o) =>
              o.habitId == habit.id &&
              o.status == OccurrenceStatus.pending &&
              dateOnly(o.dueAt).isBefore(today),
        )
        .toList()) {
      await setOccurrenceStatus(
        occurrenceId: o.id,
        status: OccurrenceStatus.missed,
      );
    }

    if (habit.kind == HabitKind.adhoc || habit.kind == HabitKind.quantity) {
      return;
    }

    final schedule = habit.schedule ?? HabitSchedule.daily();
    final earliest = earliestRetroDate(habit.createdAt);
    final from = earliest.isBefore(today) ? earliest : today;
    final dueDates = _engine.dueDatesInRange(
      schedule: schedule,
      from: from,
      to: today.add(Duration(days: horizonDays)),
      anchor: dateOnly(habit.createdAt),
    );
    final reminder = habit.reminderTimeMinutes;
    final list = <HabitOccurrence>[];
    for (final day in dueDates) {
      final dueAt = reminder == null
          ? day
          : DateTime(
              day.year,
              day.month,
              day.day,
              reminder ~/ 60,
              reminder % 60,
            );
      final isPast = dateOnly(dueAt).isBefore(today);
      list.add(
        HabitOccurrence(
          id: _uuid.v4(),
          habitId: habit.id,
          dueAt: dueAt,
          status: isPast ? OccurrenceStatus.missed : OccurrenceStatus.pending,
        ),
      );
    }
    await upsertOccurrences(list);
  }

  @override
  Stream<List<HabitQuantityLog>> watchQuantityLogs(String habitId) async* {
    yield _sortedQuantityLogs(habitId);
    final controller = _qtyControllers.putIfAbsent(
      habitId,
      () => StreamController<List<HabitQuantityLog>>.broadcast(),
    );
    yield* controller.stream;
  }

  @override
  Stream<List<HabitQuantityLog>> watchAllQuantityLogs({
    DateTime? from,
    DateTime? to,
  }) async* {
    List<HabitQuantityLog> filtered() {
      return _quantityLogs.values.where((l) {
        if (from != null && l.loggedAt.isBefore(from)) return false;
        if (to != null && !l.loggedAt.isBefore(to)) return false;
        return true;
      }).toList()
        ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    }

    yield filtered();
    yield* _allQtyController.stream.map((_) => filtered());
  }

  @override
  Future<List<HabitQuantityLog>> getQuantityLogs(
    String habitId, {
    DateTime? from,
    DateTime? to,
  }) async {
    return _quantityLogs.values.where((l) {
      if (l.habitId != habitId) return false;
      if (from != null && l.loggedAt.isBefore(from)) return false;
      if (to != null && !l.loggedAt.isBefore(to)) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
  }

  @override
  Future<void> addQuantityLog(HabitQuantityLog log) async {
    _quantityLogs[log.id] = log;
    _emitQuantityLogs(log.habitId);
  }

  @override
  Future<void> deleteQuantityLog(String id) async {
    final existing = _quantityLogs.remove(id);
    if (existing != null) _emitQuantityLogs(existing.habitId);
  }

  void dispose() {
    _habitsController.close();
    _allOccController.close();
    _allQtyController.close();
    for (final c in _occControllers.values) {
      c.close();
    }
    for (final c in _qtyControllers.values) {
      c.close();
    }
  }
}
