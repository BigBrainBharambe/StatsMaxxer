import 'package:uuid/uuid.dart';

import '../../habits/domain/habit.dart';
import '../../habits/domain/habit_occurrence.dart';
import '../../habits/domain/habit_quantity_log.dart';
import '../../money/domain/transaction.dart';
import '../../money/domain/wishlist_item.dart';
import '../domain/sync_local_store.dart';
import 'shard_codec.dart';
import 'shard_paths.dart';
import 'sync_entity_codec.dart';

/// Mutable in-memory store for sync engine unit tests.
class InMemorySyncLocalStore implements SyncLocalStore {
  InMemorySyncLocalStore({
    List<Habit>? habits,
    List<HabitOccurrence>? occurrences,
    List<HabitQuantityLog>? quantityLogs,
    List<MoneyTransaction>? transactions,
    List<WishlistItem>? wishlist,
    SyncSettingsSnapshot? settings,
    String? deviceId,
  })  : habits = List.of(habits ?? const []),
        occurrences = List.of(occurrences ?? const []),
        quantityLogs = List.of(quantityLogs ?? const []),
        transactions = List.of(transactions ?? const []),
        wishlist = List.of(wishlist ?? const []),
        settings = settings ??
            const SyncSettingsSnapshot(
              themeMode: 'system',
              visualStyle: 'classic',
              currencyCode: 'INR',
            ),
        _deviceId = deviceId ?? const Uuid().v4();

  List<Habit> habits;
  List<HabitOccurrence> occurrences;
  List<HabitQuantityLog> quantityLogs;
  List<MoneyTransaction> transactions;
  List<WishlistItem> wishlist;
  SyncSettingsSnapshot settings;

  String _deviceId;
  DateTime? lastSyncedAt;
  String? localShardIndexJson;

  @override
  Future<SyncLocalSnapshot> loadSnapshot() async {
    return SyncLocalSnapshot(
      habits: List.unmodifiable(habits),
      occurrences: List.unmodifiable(occurrences),
      quantityLogs: List.unmodifiable(quantityLogs),
      transactions: List.unmodifiable(transactions),
      wishlist: List.unmodifiable(wishlist),
      settings: settings,
    );
  }

  @override
  Future<void> applyShards(List<SyncShard> shards) async {
    final ordered = List<SyncShard>.of(shards)
      ..sort((a, b) => _applyPriority(a).compareTo(_applyPriority(b)));
    for (final shard in ordered) {
      switch (shard.kind) {
        case ShardKind.habitsMeta:
          habits = shard.items.map(SyncEntityCodec.habitFromJson).toList();
        case ShardKind.settings:
          if (shard.items.isNotEmpty) {
            final m = shard.items.first;
            settings = SyncSettingsSnapshot(
              themeMode: m['themeMode'] as String? ?? settings.themeMode,
              visualStyle: m['visualStyle'] as String? ?? settings.visualStyle,
              currencyCode:
                  m['currencyCode'] as String? ?? settings.currencyCode,
            );
          }
        case ShardKind.wishlist:
          wishlist = shard.items.map(SyncEntityCodec.wishlistFromJson).toList();
        case ShardKind.money:
          _replaceMonth(
            shard,
            decode: SyncEntityCodec.transactionFromJson,
            current: () => transactions,
            set: (v) => transactions = v,
          );
        case ShardKind.occurrences:
          _replaceMonth(
            shard,
            decode: SyncEntityCodec.occurrenceFromJson,
            current: () => occurrences,
            set: (v) => occurrences = v,
          );
        case ShardKind.quantity:
          _replaceMonth(
            shard,
            decode: SyncEntityCodec.quantityFromJson,
            current: () => quantityLogs,
            set: (v) => quantityLogs = v,
          );
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

  void _replaceMonth<T extends Object>(
    SyncShard shard, {
    required T Function(Map<String, dynamic>) decode,
    required List<T> Function() current,
    required void Function(List<T>) set,
  }) {
    final ym = ShardPaths.parseYearMonth(shard.path);
    if (ym == null) return;
    final (year, month) = ym;
    final incoming = shard.items.map(decode).toList();
    final kept = current().where((row) {
      final d = _rowDate(row);
      return d.year != year || d.month != month;
    }).toList();
    set([...kept, ...incoming]);
  }

  DateTime _rowDate(Object row) {
    if (row is MoneyTransaction) return row.date;
    if (row is HabitOccurrence) return row.dueAt;
    if (row is HabitQuantityLog) return row.loggedAt;
    throw ArgumentError('Unexpected row type ${row.runtimeType}');
  }

  @override
  Future<String> getOrCreateDeviceId() async => _deviceId;

  @override
  Future<DateTime?> getLastSyncedAt() async => lastSyncedAt;

  @override
  Future<void> setLastSyncedAt(DateTime at) async {
    lastSyncedAt = at.toUtc();
  }

  @override
  Future<String?> getLocalShardIndexJson() async => localShardIndexJson;

  @override
  Future<void> setLocalShardIndexJson(String json) async {
    localShardIndexJson = json;
  }
}
