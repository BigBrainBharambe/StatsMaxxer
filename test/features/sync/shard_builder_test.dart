import 'package:flutter_test/flutter_test.dart';
import 'package:stat_maxxer/features/habits/domain/habit.dart';
import 'package:stat_maxxer/features/habits/domain/habit_occurrence.dart';
import 'package:stat_maxxer/features/money/domain/transaction.dart';
import 'package:stat_maxxer/features/sync/data/shard_builder.dart';
import 'package:stat_maxxer/features/sync/data/shard_codec.dart';
import 'package:stat_maxxer/features/sync/data/shard_paths.dart';
import 'package:stat_maxxer/features/sync/data/sync_entity_codec.dart';
import 'package:stat_maxxer/features/sync/domain/sync_local_store.dart';
import 'package:stat_maxxer/features/sync/domain/sync_manifest.dart';

void main() {
  final builder = const ShardBuilder();
  final resolver = const ShardConflictResolver();

  SyncLocalSnapshot snapshotWithTx(List<MoneyTransaction> txs) {
    return SyncLocalSnapshot(
      habits: const [],
      occurrences: const [],
      quantityLogs: const [],
      transactions: txs,
      wishlist: const [],
      settings: const SyncSettingsSnapshot(
        themeMode: 'system',
        visualStyle: 'classic',
        currencyCode: 'INR',
      ),
    );
  }

  test('splits transactions into monthly money shards', () {
    final shards = builder.build(
      snapshotWithTx([
        MoneyTransaction(
          id: 'a',
          amount: 10,
          type: TransactionType.expense,
          category: 'Food',
          date: DateTime(2026, 7, 2),
        ),
        MoneyTransaction(
          id: 'b',
          amount: 20,
          type: TransactionType.income,
          category: 'Salary',
          date: DateTime(2026, 8, 1),
        ),
        MoneyTransaction(
          id: 'c',
          amount: 5,
          type: TransactionType.expense,
          category: 'Food',
          date: DateTime(2026, 7, 18),
        ),
      ]),
      updatedAt: DateTime.utc(2026, 8, 2),
    );

    final money = shards.where((s) => s.kind == ShardKind.money).toList();
    expect(money.map((s) => s.path), unorderedEquals([
      ShardPaths.moneyMonth(2026, 7),
      ShardPaths.moneyMonth(2026, 8),
    ]));
    final july = money.firstWhere((s) => s.path.contains('/07.json'));
    expect(july.items.map((e) => e['id']), ['a', 'c']);
  });

  test('splits occurrences by dueAt month', () {
    final shards = builder.build(
      SyncLocalSnapshot(
        habits: [
          Habit(
            id: 'h1',
            name: 'Run',
            createdAt: DateTime(2026, 1, 1),
          ),
        ],
        occurrences: [
          HabitOccurrence(
            id: 'o1',
            habitId: 'h1',
            dueAt: DateTime(2026, 6, 10),
            status: OccurrenceStatus.completed,
          ),
          HabitOccurrence(
            id: 'o2',
            habitId: 'h1',
            dueAt: DateTime(2026, 7, 1),
            status: OccurrenceStatus.pending,
          ),
        ],
        quantityLogs: const [],
        transactions: const [],
        wishlist: const [],
        settings: const SyncSettingsSnapshot(
          themeMode: 'dark',
          visualStyle: 'cyber',
          currencyCode: 'USD',
        ),
      ),
      updatedAt: DateTime.utc(2026, 8, 2),
    );

    expect(
      shards.where((s) => s.kind == ShardKind.occurrences).map((s) => s.path),
      unorderedEquals([
        ShardPaths.occurrencesMonth(2026, 6),
        ShardPaths.occurrencesMonth(2026, 7),
      ]),
    );
  });

  test('round-trips shard codec with stable checksum', () {
    final shard = SyncShard(
      kind: ShardKind.money,
      path: ShardPaths.moneyMonth(2026, 7),
      updatedAt: DateTime.utc(2026, 8, 1),
      items: [
        SyncEntityCodec.transactionToJson(
          MoneyTransaction(
            id: 't1',
            amount: 9,
            type: TransactionType.expense,
            category: 'Food',
            date: DateTime(2026, 7, 4),
          ),
        ),
      ],
    );
    final bytes = shard.encodeBytes();
    final decoded = SyncShard.decodeBytes(bytes);
    expect(decoded.checksum(), shard.checksum());
    expect(decoded.items.single['id'], 't1');
  });

  test('conflict resolver pulls newer remote and pushes newer local', () {
    final local = SyncShard(
      kind: ShardKind.money,
      path: ShardPaths.moneyMonth(2026, 7),
      updatedAt: DateTime.utc(2026, 8, 2),
      items: [
        {'id': 'local', 'amount': 1, 'type': 'expense', 'category': 'Food', 'date': '2026-07-01T00:00:00.000', 'note': '', 'merchant': '', 'source': 'manual'},
      ],
    );
    final remoteOlder = SyncShardIndexEntry(
      path: local.path,
      checksum: 'different',
      updatedAt: DateTime.utc(2026, 8, 1),
    );
    final planPush = resolver.plan(
      localByPath: {local.path: local},
      remoteIndex: {local.path: remoteOlder},
    );
    expect(planPush.toPush, [local.path]);

    final remoteNewer = remoteOlder.copyWith(
      updatedAt: DateTime.utc(2026, 8, 3),
    );
    final planPull = resolver.plan(
      localByPath: {local.path: local},
      remoteIndex: {local.path: remoteNewer},
    );
    expect(planPull.toPull, [local.path]);
  });

  test('equal checksum skips transfer', () {
    final shard = SyncShard(
      kind: ShardKind.settings,
      path: ShardPaths.metaSettings,
      updatedAt: DateTime.utc(2026, 8, 1),
      items: [
        SyncEntityCodec.settingsToJson(
          themeMode: 'system',
          visualStyle: 'classic',
          currencyCode: 'INR',
        ),
      ],
    );
    final plan = resolver.plan(
      localByPath: {shard.path: shard},
      remoteIndex: {
        shard.path: SyncShardIndexEntry(
          path: shard.path,
          checksum: shard.checksum(),
          updatedAt: DateTime.utc(2026, 7, 1),
        ),
      },
    );
    expect(plan.unchanged, [shard.path]);
    expect(plan.toPull, isEmpty);
    expect(plan.toPush, isEmpty);
  });
}
