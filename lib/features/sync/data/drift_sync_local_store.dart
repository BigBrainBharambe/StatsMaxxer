import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../habits/domain/habit.dart';
import '../../habits/domain/habit_occurrence.dart';
import '../../habits/domain/habit_quantity_log.dart';
import '../../habits/domain/quantity_window_goal.dart';
import '../../money/domain/transaction.dart';
import '../../money/domain/wishlist_item.dart';
import '../../settings/domain/app_currency.dart';
import '../domain/sync_local_store.dart';
import 'shard_codec.dart';
import 'shard_paths.dart';
import 'sync_entity_codec.dart';

/// Drift + SharedPreferences backed sync store.
class DriftSyncLocalStore implements SyncLocalStore {
  DriftSyncLocalStore({
    required AppDatabase db,
    required SharedPreferences prefs,
  })  : _db = db,
        _prefs = prefs;

  static const _deviceIdKey = 'sync_device_id';
  static const _lastSyncKey = 'sync_last_synced_at';
  static const _localIndexKey = 'sync_local_shard_index';

  final AppDatabase _db;
  final SharedPreferences _prefs;

  @override
  Future<SyncLocalSnapshot> loadSnapshot() async {
    final habitRows = await _db.select(_db.habits).get();
    final occRows = await _db.select(_db.habitOccurrences).get();
    final qtyRows = await _db.select(_db.habitQuantityLogs).get();
    final txRows = await _db.select(_db.transactions).get();
    final wishRows = await _db.select(_db.wishlistItems).get();

    return SyncLocalSnapshot(
      habits: habitRows.map(_mapHabit).toList(),
      occurrences: occRows.map(_mapOccurrence).toList(),
      quantityLogs: qtyRows.map(_mapQuantity).toList(),
      transactions: txRows.map(_mapTx).toList(),
      wishlist: wishRows.map(_mapWish).toList(),
      settings: SyncSettingsSnapshot(
        themeMode: _prefs.getString('theme_mode') ?? 'system',
        visualStyle: _prefs.getString('visual_style') ?? 'classic',
        currencyCode:
            AppCurrency.fromCode(_prefs.getString('currency_code')).code,
      ),
    );
  }

  @override
  Future<void> applyShards(List<SyncShard> shards) async {
    final ordered = List<SyncShard>.of(shards)
      ..sort((a, b) => _applyPriority(a).compareTo(_applyPriority(b)));
    for (final shard in ordered) {
      switch (shard.kind) {
        case ShardKind.habitsMeta:
          await _applyHabits(shard);
        case ShardKind.settings:
          await _applySettings(shard);
        case ShardKind.wishlist:
          await _applyWishlist(shard);
        case ShardKind.money:
          await _applyMoneyMonth(shard);
        case ShardKind.occurrences:
          await _applyOccurrencesMonth(shard);
        case ShardKind.quantity:
          await _applyQuantityMonth(shard);
      }
    }
  }

  int _applyPriority(SyncShard shard) {
    return switch (shard.kind) {
      ShardKind.habitsMeta => 0,
      ShardKind.settings => 1,
      ShardKind.wishlist => 2,
      ShardKind.money => 3,
      ShardKind.occurrences => 4,
      ShardKind.quantity => 5,
    };
  }

  Future<void> _applyHabits(SyncShard shard) async {
    final incoming = shard.items.map(SyncEntityCodec.habitFromJson).toList();
    final ids = incoming.map((h) => h.id).toSet();
    await _db.transaction(() async {
      final existing = await _db.select(_db.habits).get();
      for (final row in existing) {
        if (!ids.contains(row.id)) {
          await (_db.delete(_db.habits)..where((t) => t.id.equals(row.id))).go();
        }
      }
      for (final h in incoming) {
        await _db.into(_db.habits).insert(
              _habitCompanion(h),
              mode: InsertMode.insertOrReplace,
            );
      }
    });
  }

  Future<void> _applySettings(SyncShard shard) async {
    if (shard.items.isEmpty) return;
    final m = shard.items.first;
    final theme = m['themeMode'] as String?;
    final style = m['visualStyle'] as String?;
    final currency = m['currencyCode'] as String?;
    if (theme != null) await _prefs.setString('theme_mode', theme);
    if (style != null) await _prefs.setString('visual_style', style);
    if (currency != null) {
      await _prefs.setString(
        'currency_code',
        AppCurrency.fromCode(currency).code,
      );
    }
  }

  Future<void> _applyWishlist(SyncShard shard) async {
    final incoming = shard.items.map(SyncEntityCodec.wishlistFromJson).toList();
    final ids = incoming.map((i) => i.id).toSet();
    await _db.transaction(() async {
      final existing = await _db.select(_db.wishlistItems).get();
      for (final row in existing) {
        if (!ids.contains(row.id)) {
          await (_db.delete(_db.wishlistItems)
                ..where((t) => t.id.equals(row.id)))
              .go();
        }
      }
      for (final item in incoming) {
        await _db.into(_db.wishlistItems).insert(
              _wishCompanion(item),
              mode: InsertMode.insertOrReplace,
            );
      }
    });
  }

  Future<void> _applyMoneyMonth(SyncShard shard) async {
    final ym = ShardPaths.parseYearMonth(shard.path);
    if (ym == null) return;
    final (year, month) = ym;
    final start = DateTime(year, month);
    final end = DateTime(year, month + 1);
    final incoming =
        shard.items.map(SyncEntityCodec.transactionFromJson).toList();

    await _db.transaction(() async {
      await (_db.delete(_db.transactions)
            ..where((t) => t.date.isBiggerOrEqualValue(start))
            ..where((t) => t.date.isSmallerThanValue(end)))
          .go();
      for (final tx in incoming) {
        await _db.into(_db.transactions).insert(
              _txCompanion(tx),
              mode: InsertMode.insertOrReplace,
            );
      }
    });
  }

  Future<void> _applyOccurrencesMonth(SyncShard shard) async {
    final ym = ShardPaths.parseYearMonth(shard.path);
    if (ym == null) return;
    final (year, month) = ym;
    final start = DateTime(year, month);
    final end = DateTime(year, month + 1);
    final incoming =
        shard.items.map(SyncEntityCodec.occurrenceFromJson).toList();

    await _db.transaction(() async {
      await (_db.delete(_db.habitOccurrences)
            ..where((t) => t.dueAt.isBiggerOrEqualValue(start))
            ..where((t) => t.dueAt.isSmallerThanValue(end)))
          .go();
      for (final o in incoming) {
        await _db.into(_db.habitOccurrences).insert(
              _occCompanion(o),
              mode: InsertMode.insertOrReplace,
            );
      }
    });
  }

  Future<void> _applyQuantityMonth(SyncShard shard) async {
    final ym = ShardPaths.parseYearMonth(shard.path);
    if (ym == null) return;
    final (year, month) = ym;
    final start = DateTime(year, month);
    final end = DateTime(year, month + 1);
    final incoming =
        shard.items.map(SyncEntityCodec.quantityFromJson).toList();

    await _db.transaction(() async {
      await (_db.delete(_db.habitQuantityLogs)
            ..where((t) => t.loggedAt.isBiggerOrEqualValue(start))
            ..where((t) => t.loggedAt.isSmallerThanValue(end)))
          .go();
      for (final log in incoming) {
        await _db.into(_db.habitQuantityLogs).insert(
              _qtyCompanion(log),
              mode: InsertMode.insertOrReplace,
            );
      }
    });
  }

  Habit _mapHabit(HabitRow row) => Habit(
        id: row.id,
        name: row.name,
        createdAt: row.createdAt,
        archived: row.archived,
        kind: HabitKind.values.firstWhere(
          (k) => k.name == row.kind,
          orElse: () => HabitKind.repeatable,
        ),
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
        status: OccurrenceStatus.values.firstWhere(
          (s) => s.name == row.status,
          orElse: () => OccurrenceStatus.pending,
        ),
        completedAt: row.completedAt,
      );

  HabitQuantityLog _mapQuantity(HabitQuantityLogRow row) => HabitQuantityLog(
        id: row.id,
        habitId: row.habitId,
        loggedAt: row.loggedAt,
        quantity: row.quantity,
      );

  MoneyTransaction _mapTx(TransactionRow row) => MoneyTransaction(
        id: row.id,
        amount: row.amount,
        type: TransactionTypeX.parse(row.type),
        category: row.category,
        note: row.note,
        merchant: row.merchant,
        externalId: row.externalId,
        source: row.source == 'import'
            ? TransactionSource.import
            : TransactionSource.manual,
        date: row.date,
      );

  WishlistItem _mapWish(WishlistItemRow row) {
    final target = TransactionTypeX.parse(row.targetType);
    final safeTarget = TransactionTypeX.wishlistTargets.contains(target)
        ? target
        : TransactionType.expense;
    return WishlistItem(
      id: row.id,
      name: row.name,
      notes: row.notes,
      estimatedPrice: row.estimatedPrice,
      createdAt: row.createdAt,
      boughtAt: row.boughtAt,
      transactionId: row.transactionId,
      isRecurring: row.isRecurring,
      recurrenceInterval: row.recurrenceInterval,
      recurrenceUnit: row.recurrenceUnit == null
          ? null
          : WishlistRecurrenceUnitX.parse(row.recurrenceUnit),
      nextDue: row.nextDue,
      targetType: safeTarget,
    );
  }

  HabitsCompanion _habitCompanion(Habit habit) => HabitsCompanion.insert(
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

  HabitOccurrencesCompanion _occCompanion(HabitOccurrence o) =>
      HabitOccurrencesCompanion.insert(
        id: o.id,
        habitId: o.habitId,
        dueAt: o.dueAt,
        status: Value(o.status.name),
        completedAt: Value(o.completedAt),
      );

  HabitQuantityLogsCompanion _qtyCompanion(HabitQuantityLog log) =>
      HabitQuantityLogsCompanion.insert(
        id: log.id,
        habitId: log.habitId,
        loggedAt: log.loggedAt,
        quantity: Value(log.quantity.toDouble()),
      );

  TransactionsCompanion _txCompanion(MoneyTransaction t) =>
      TransactionsCompanion.insert(
        id: t.id,
        amount: t.amount,
        type: t.type.name,
        category: t.category,
        note: Value(t.note),
        merchant: Value(t.merchant),
        externalId: Value(t.externalId),
        source: Value(
          t.source == TransactionSource.import ? 'import' : 'manual',
        ),
        date: t.date,
      );

  WishlistItemsCompanion _wishCompanion(WishlistItem item) =>
      WishlistItemsCompanion.insert(
        id: item.id,
        name: item.name,
        notes: Value(item.notes),
        estimatedPrice: Value(item.estimatedPrice),
        createdAt: item.createdAt,
        boughtAt: Value(item.boughtAt),
        transactionId: Value(item.transactionId),
        isRecurring: Value(item.isRecurring),
        recurrenceInterval: Value(item.recurrenceInterval),
        recurrenceUnit: Value(item.recurrenceUnit?.name),
        nextDue: Value(item.nextDue),
        targetType: Value(item.targetType.name),
      );

  @override
  Future<String> getOrCreateDeviceId() async {
    final existing = _prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = const Uuid().v4();
    await _prefs.setString(_deviceIdKey, id);
    return id;
  }

  @override
  Future<DateTime?> getLastSyncedAt() async {
    final raw = _prefs.getString(_lastSyncKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  @override
  Future<void> setLastSyncedAt(DateTime at) async {
    await _prefs.setString(_lastSyncKey, at.toUtc().toIso8601String());
  }

  @override
  Future<String?> getLocalShardIndexJson() async =>
      _prefs.getString(_localIndexKey);

  @override
  Future<void> setLocalShardIndexJson(String json) async {
    await _prefs.setString(_localIndexKey, json);
  }
}
