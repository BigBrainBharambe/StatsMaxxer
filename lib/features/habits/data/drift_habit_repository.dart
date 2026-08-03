import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/date_utils.dart';
import '../domain/habit.dart';
import '../domain/habit_occurrence.dart';
import '../domain/habit_quantity_log.dart';
import '../domain/habit_repository.dart';
import '../domain/habit_retro_rules.dart';
import '../domain/occurrence_day_collapse.dart';
import '../domain/occurrence_engine.dart';
import '../domain/quantity_window_goal.dart';

class DriftHabitRepository implements HabitRepository {
  DriftHabitRepository(this._db, {OccurrenceEngine? engine, Uuid? uuid})
      : _engine = engine ?? const OccurrenceEngine(),
        _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final OccurrenceEngine _engine;
  final Uuid _uuid;

  HabitKind _parseKind(String raw) {
    return HabitKind.values.firstWhere(
      (k) => k.name == raw,
      orElse: () => HabitKind.repeatable,
    );
  }

  Habit _mapHabit(HabitRow row) => Habit(
        id: row.id,
        name: row.name,
        createdAt: row.createdAt,
        archived: row.archived,
        kind: _parseKind(row.kind),
        schedule: HabitSchedule.tryDecode(row.scheduleJson),
        quantityGoal: QuantityWindowGoal.tryDecode(row.goalJson),
        reminderTimeMinutes: row.reminderTimeMinutes,
        colorValue: row.colorValue,
        iconName: row.iconName,
      );

  HabitOccurrence _mapOccurrence(HabitOccurrenceRow row) => HabitOccurrence(
        id: row.id,
        habitId: row.habitId,
        dueAt: row.dueAt,
        status: _parseStatus(row.status),
        completedAt: row.completedAt,
      );

  HabitQuantityLog _mapQuantityLog(HabitQuantityLogRow row) => HabitQuantityLog(
        id: row.id,
        habitId: row.habitId,
        loggedAt: row.loggedAt,
        quantity: row.quantity,
      );

  OccurrenceStatus _parseStatus(String raw) {
    return OccurrenceStatus.values.firstWhere(
      (s) => s.name == raw,
      orElse: () => OccurrenceStatus.pending,
    );
  }

  HabitsCompanion _habitCompanion(Habit habit) {
    return HabitsCompanion.insert(
      id: habit.id,
      name: habit.name,
      createdAt: habit.createdAt,
      archived: Value(habit.archived),
      kind: Value(habit.kind.name),
      scheduleJson: Value(habit.schedule?.encode()),
      goalJson: Value(habit.quantityGoal?.encode()),
      reminderTimeMinutes: Value(habit.reminderTimeMinutes),
      colorValue: Value(habit.colorValue),
      iconName: Value(habit.iconName),
    );
  }

  HabitOccurrencesCompanion _occurrenceCompanion(HabitOccurrence o) {
    return HabitOccurrencesCompanion.insert(
      id: o.id,
      habitId: o.habitId,
      dueAt: o.dueAt,
      status: Value(o.status.name),
      completedAt: Value(o.completedAt),
    );
  }

  HabitQuantityLogsCompanion _quantityLogCompanion(HabitQuantityLog log) {
    return HabitQuantityLogsCompanion.insert(
      id: log.id,
      habitId: log.habitId,
      loggedAt: log.loggedAt,
      quantity: Value(log.quantity.toDouble()),
    );
  }

  @override
  Stream<List<Habit>> watchHabits({bool includeArchived = false}) {
    final query = includeArchived
        ? _db.select(_db.habits)
        : (_db.select(_db.habits)..where((t) => t.archived.equals(false)));
    query.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch().map((rows) => rows.map(_mapHabit).toList());
  }

  @override
  Future<List<Habit>> getHabits({bool includeArchived = false}) async {
    final query = includeArchived
        ? _db.select(_db.habits)
        : (_db.select(_db.habits)..where((t) => t.archived.equals(false)));
    query.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    final rows = await query.get();
    return rows.map(_mapHabit).toList();
  }

  @override
  Future<Habit?> getHabit(String id) async {
    final row = await (_db.select(_db.habits)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _mapHabit(row);
  }

  @override
  Future<void> addHabit(Habit habit) async {
    await _db.into(_db.habits).insert(_habitCompanion(habit));
  }

  @override
  Future<void> updateHabit(Habit habit) async {
    await (_db.update(_db.habits)..where((t) => t.id.equals(habit.id))).write(
          HabitsCompanion(
            name: Value(habit.name),
            archived: Value(habit.archived),
            kind: Value(habit.kind.name),
            scheduleJson: Value(habit.schedule?.encode()),
            goalJson: Value(habit.quantityGoal?.encode()),
            reminderTimeMinutes: Value(habit.reminderTimeMinutes),
            colorValue: Value(habit.colorValue),
            iconName: Value(habit.iconName),
          ),
        );
  }

  @override
  Future<void> archiveHabit(String id, {bool archived = true}) async {
    await (_db.update(_db.habits)..where((t) => t.id.equals(id))).write(
          HabitsCompanion(archived: Value(archived)),
        );
  }

  @override
  Future<void> deleteHabit(String id) async {
    await (_db.delete(_db.habits)..where((t) => t.id.equals(id))).go();
  }

  @override
  Stream<List<HabitOccurrence>> watchOccurrences(String habitId) {
    final query = _db.select(_db.habitOccurrences)
      ..where((t) => t.habitId.equals(habitId))
      ..orderBy([(t) => OrderingTerm.desc(t.dueAt)]);
    return query.watch().map((rows) => rows.map(_mapOccurrence).toList());
  }

  @override
  Stream<List<HabitOccurrence>> watchAllOccurrences({
    DateTime? from,
    DateTime? to,
  }) {
    final query = _db.select(_db.habitOccurrences);
    if (from != null) {
      query.where((t) => t.dueAt.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      query.where((t) => t.dueAt.isSmallerThanValue(to));
    }
    query.orderBy([(t) => OrderingTerm.asc(t.dueAt)]);
    return query.watch().map((rows) => rows.map(_mapOccurrence).toList());
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
    final query = _db.select(_db.habitOccurrences)
      ..where((t) =>
          t.dueAt.isBiggerOrEqualValue(from) & t.dueAt.isSmallerThanValue(to));
    if (habitId != null) {
      query.where((t) => t.habitId.equals(habitId));
    }
    query.orderBy([(t) => OrderingTerm.asc(t.dueAt)]);
    final rows = await query.get();
    return rows.map(_mapOccurrence).toList();
  }

  @override
  Future<HabitOccurrence?> getOccurrence(String id) async {
    final row = await (_db.select(_db.habitOccurrences)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _mapOccurrence(row);
  }

  @override
  Future<void> upsertOccurrence(HabitOccurrence occurrence) async {
    await _db.into(_db.habitOccurrences).insertOnConflictUpdate(
          _occurrenceCompanion(occurrence),
        );
  }

  @override
  Future<void> upsertOccurrences(List<HabitOccurrence> occurrences) async {
    if (occurrences.isEmpty) return;
    // Unique index is (habitId, dueAt) exact; also block same calendar day so
    // reminder re-sync cannot insert a second row that breaks streaks.
    final habitIds = occurrences.map((o) => o.habitId).toSet();
    final existingDays = <String>{};
    for (final habitId in habitIds) {
      final rows = await (_db.select(_db.habitOccurrences)
            ..where((t) => t.habitId.equals(habitId)))
          .get();
      for (final row in rows) {
        final d = dateOnly(row.dueAt);
        existingDays.add('$habitId-${d.year}-${d.month}-${d.day}');
      }
    }
    final toInsert = <HabitOccurrence>[];
    for (final o in occurrences) {
      final d = dateOnly(o.dueAt);
      final key = '${o.habitId}-${d.year}-${d.month}-${d.day}';
      if (existingDays.contains(key)) continue;
      existingDays.add(key);
      toInsert.add(o);
    }
    if (toInsert.isEmpty) return;
    await _db.batch((batch) {
      for (final o in toInsert) {
        batch.insert(
          _db.habitOccurrences,
          _occurrenceCompanion(o),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  @override
  Future<void> setOccurrenceStatus({
    required String occurrenceId,
    required OccurrenceStatus status,
    DateTime? completedAt,
  }) async {
    await (_db.update(_db.habitOccurrences)
          ..where((t) => t.id.equals(occurrenceId)))
        .write(
      HabitOccurrencesCompanion(
        status: Value(status.name),
        completedAt: Value(
          status == OccurrenceStatus.completed
              ? (completedAt ?? DateTime.now())
              : null,
        ),
      ),
    );
  }

  @override
  Future<int> dedupeOccurrenceDays({String? habitId}) async {
    final query = _db.select(_db.habitOccurrences);
    if (habitId != null) {
      query.where((t) => t.habitId.equals(habitId));
    }
    final rows = await query.get();
    final losers = duplicateOccurrenceLosers(rows.map(_mapOccurrence).toList());
    if (losers.isEmpty) return 0;
    await (_db.delete(_db.habitOccurrences)
          ..where((t) => t.id.isIn(losers.map((o) => o.id))))
        .go();
    return losers.length;
  }

  /// Materialize upcoming occurrences for a habit and mark past pending as missed.
  @override
  Future<void> syncHabitSchedule(
    Habit habit, {
    DateTime? now,
    int horizonDays = 60,
  }) async {
    final clock = now ?? DateTime.now();
    final today = dateOnly(clock);

    // Legacy DBs may still hold midnight + reminder duplicates for one day.
    await dedupeOccurrenceDays(habitId: habit.id);

    // Mark missed
    final pendingPast = await (_db.select(_db.habitOccurrences)
          ..where(
            (t) =>
                t.habitId.equals(habit.id) &
                t.status.equals(OccurrenceStatus.pending.name) &
                t.dueAt.isSmallerThanValue(today),
          ))
        .get();
    for (final row in pendingPast) {
      await setOccurrenceStatus(
        occurrenceId: row.id,
        status: OccurrenceStatus.missed,
      );
    }

    if (habit.kind == HabitKind.adhoc || habit.kind == HabitKind.quantity) {
      return;
    }

    final schedule = habit.schedule ?? HabitSchedule.daily();
    // Include the retro window before creation so past dues can be marked.
    final earliest = earliestRetroDate(habit.createdAt);
    final from = earliest.isBefore(today) ? earliest : today;
    final to = today.add(Duration(days: horizonDays));
    final dueDates = _engine.dueDatesInRange(
      schedule: schedule,
      from: from,
      to: to,
      anchor: dateOnly(habit.createdAt),
    );

    final reminder = habit.reminderTimeMinutes;
    final toInsert = <HabitOccurrence>[];
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
      toInsert.add(
        HabitOccurrence(
          id: _uuid.v4(),
          habitId: habit.id,
          dueAt: dueAt,
          status: isPast ? OccurrenceStatus.missed : OccurrenceStatus.pending,
        ),
      );
    }
    await upsertOccurrences(toInsert);
  }

  @override
  Stream<List<HabitQuantityLog>> watchQuantityLogs(String habitId) {
    final query = _db.select(_db.habitQuantityLogs)
      ..where((t) => t.habitId.equals(habitId))
      ..orderBy([(t) => OrderingTerm.desc(t.loggedAt)]);
    return query.watch().map((rows) => rows.map(_mapQuantityLog).toList());
  }

  @override
  Stream<List<HabitQuantityLog>> watchAllQuantityLogs({
    DateTime? from,
    DateTime? to,
  }) {
    final query = _db.select(_db.habitQuantityLogs);
    if (from != null) {
      query.where((t) => t.loggedAt.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      query.where((t) => t.loggedAt.isSmallerThanValue(to));
    }
    query.orderBy([(t) => OrderingTerm.asc(t.loggedAt)]);
    return query.watch().map((rows) => rows.map(_mapQuantityLog).toList());
  }

  @override
  Future<List<HabitQuantityLog>> getQuantityLogs(
    String habitId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final query = _db.select(_db.habitQuantityLogs)
      ..where((t) => t.habitId.equals(habitId));
    if (from != null) {
      query.where((t) => t.loggedAt.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      query.where((t) => t.loggedAt.isSmallerThanValue(to));
    }
    query.orderBy([(t) => OrderingTerm.asc(t.loggedAt)]);
    final rows = await query.get();
    return rows.map(_mapQuantityLog).toList();
  }

  @override
  Future<void> addQuantityLog(HabitQuantityLog log) async {
    await _db.into(_db.habitQuantityLogs).insert(_quantityLogCompanion(log));
  }

  @override
  Future<void> deleteQuantityLog(String id) async {
    await (_db.delete(_db.habitQuantityLogs)..where((t) => t.id.equals(id)))
        .go();
  }
}
