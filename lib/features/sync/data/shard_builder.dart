import '../../habits/domain/habit_occurrence.dart';
import '../../habits/domain/habit_quantity_log.dart';
import '../../money/domain/transaction.dart';
import '../domain/sync_local_store.dart';
import '../domain/sync_manifest.dart';
import 'shard_codec.dart';
import 'shard_paths.dart';
import 'sync_entity_codec.dart';

/// Splits a local snapshot into Drive shards (meta + monthly money/habits).
class ShardBuilder {
  const ShardBuilder();

  List<SyncShard> build(
    SyncLocalSnapshot snapshot, {
    required DateTime updatedAt,
  }) {
    final at = updatedAt.toUtc();
    return [
      SyncShard(
        kind: ShardKind.habitsMeta,
        path: ShardPaths.metaHabits,
        updatedAt: at,
        items: snapshot.habits.map(SyncEntityCodec.habitToJson).toList(),
      ),
      SyncShard(
        kind: ShardKind.settings,
        path: ShardPaths.metaSettings,
        updatedAt: at,
        items: [
          SyncEntityCodec.settingsToJson(
            themeMode: snapshot.settings.themeMode,
            visualStyle: snapshot.settings.visualStyle,
            currencyCode: snapshot.settings.currencyCode,
          ),
        ],
      ),
      SyncShard(
        kind: ShardKind.wishlist,
        path: ShardPaths.metaWishlist,
        updatedAt: at,
        items: snapshot.wishlist.map(SyncEntityCodec.wishlistToJson).toList(),
      ),
      ..._moneyShards(snapshot.transactions, at),
      ..._occurrenceShards(snapshot.occurrences, at),
      ..._quantityShards(snapshot.quantityLogs, at),
    ];
  }

  List<SyncShard> _moneyShards(List<MoneyTransaction> txs, DateTime at) {
    final byMonth = <(int, int), List<Map<String, dynamic>>>{};
    for (final tx in txs) {
      final key = (tx.date.year, tx.date.month);
      byMonth.putIfAbsent(key, () => []).add(SyncEntityCodec.transactionToJson(tx));
    }
    return [
      for (final e in byMonth.entries)
        SyncShard(
          kind: ShardKind.money,
          path: ShardPaths.moneyMonth(e.key.$1, e.key.$2),
          updatedAt: at,
          items: _sortedById(e.value),
        ),
    ];
  }

  List<SyncShard> _occurrenceShards(
    List<HabitOccurrence> rows,
    DateTime at,
  ) {
    final byMonth = <(int, int), List<Map<String, dynamic>>>{};
    for (final o in rows) {
      final key = (o.dueAt.year, o.dueAt.month);
      byMonth
          .putIfAbsent(key, () => [])
          .add(SyncEntityCodec.occurrenceToJson(o));
    }
    return [
      for (final e in byMonth.entries)
        SyncShard(
          kind: ShardKind.occurrences,
          path: ShardPaths.occurrencesMonth(e.key.$1, e.key.$2),
          updatedAt: at,
          items: _sortedById(e.value),
        ),
    ];
  }

  List<SyncShard> _quantityShards(
    List<HabitQuantityLog> rows,
    DateTime at,
  ) {
    final byMonth = <(int, int), List<Map<String, dynamic>>>{};
    for (final log in rows) {
      final key = (log.loggedAt.year, log.loggedAt.month);
      byMonth
          .putIfAbsent(key, () => [])
          .add(SyncEntityCodec.quantityToJson(log));
    }
    return [
      for (final e in byMonth.entries)
        SyncShard(
          kind: ShardKind.quantity,
          path: ShardPaths.quantityMonth(e.key.$1, e.key.$2),
          updatedAt: at,
          items: _sortedById(e.value),
        ),
    ];
  }

  List<Map<String, dynamic>> _sortedById(List<Map<String, dynamic>> items) {
    return items
      ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
  }
}

/// Decides which shards to pull vs push given remote manifest + local shards.
class ShardDiff {
  const ShardDiff({
    required this.toPull,
    required this.toPush,
    required this.unchanged,
  });

  final List<String> toPull;
  final List<String> toPush;
  final List<String> unchanged;
}

class ShardConflictResolver {
  const ShardConflictResolver();

  /// Last-write-wins per shard path using [updatedAt], then checksum equality.
  ShardDiff plan({
    required Map<String, SyncShard> localByPath,
    required Map<String, SyncShardIndexEntry> remoteIndex,
  }) {
    final paths = <String>{
      ...localByPath.keys,
      ...remoteIndex.keys,
    };
    final toPull = <String>[];
    final toPush = <String>[];
    final unchanged = <String>[];

    for (final path in paths) {
      final local = localByPath[path];
      final remote = remoteIndex[path];

      if (local == null && remote != null) {
        toPull.add(path);
        continue;
      }
      if (local != null && remote == null) {
        toPush.add(path);
        continue;
      }
      if (local == null || remote == null) continue;

      final localChecksum = local.checksum();
      if (localChecksum == remote.checksum) {
        unchanged.add(path);
        continue;
      }

      final localAt = local.updatedAt.toUtc();
      final remoteAt = remote.updatedAt.toUtc();
      if (remoteAt.isAfter(localAt)) {
        toPull.add(path);
      } else if (localAt.isAfter(remoteAt)) {
        toPush.add(path);
      } else {
        // Same timestamp, different checksum — prefer remote (conservative).
        toPull.add(path);
      }
    }

    toPull.sort();
    toPush.sort();
    unchanged.sort();
    return ShardDiff(toPull: toPull, toPush: toPush, unchanged: unchanged);
  }
}
