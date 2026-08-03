import 'package:flutter_test/flutter_test.dart';
import 'package:stat_maxxer/features/money/domain/transaction.dart';
import 'package:stat_maxxer/features/sync/data/fake_drive_client.dart';
import 'package:stat_maxxer/features/sync/data/in_memory_sync_local_store.dart';
import 'package:stat_maxxer/features/sync/data/shard_paths.dart';
import 'package:stat_maxxer/features/sync/data/sync_engine.dart';
import 'package:stat_maxxer/features/sync/domain/sync_local_store.dart';

void main() {
  test('first sync pushes shards to fake Drive', () async {
    final drive = FakeDriveClient();
    final store = InMemorySyncLocalStore(
      deviceId: 'device-a',
      transactions: [
        MoneyTransaction(
          id: 't1',
          amount: 12,
          type: TransactionType.expense,
          category: 'Food',
          date: DateTime(2026, 7, 10),
        ),
      ],
      settings: const SyncSettingsSnapshot(
        themeMode: 'system',
        visualStyle: 'classic',
        currencyCode: 'INR',
      ),
    );

    var now = DateTime.utc(2026, 8, 2, 10);
    final engine = SyncEngine.forTesting(
      localStore: store,
      drive: drive,
      clock: () => now,
    );

    final result = await engine.sync();
    expect(result.pushed, greaterThanOrEqualTo(1));
    expect(drive.files.containsKey(ShardPaths.manifest), isTrue);
    expect(drive.files.containsKey(ShardPaths.moneyMonth(2026, 7)), isTrue);
    expect(store.lastSyncedAt, now);
  });

  test('second device pulls money shard (LWW)', () async {
    final drive = FakeDriveClient();
    final deviceA = InMemorySyncLocalStore(
      deviceId: 'a',
      transactions: [
        MoneyTransaction(
          id: 't1',
          amount: 50,
          type: TransactionType.income,
          category: 'Salary',
          date: DateTime(2026, 7, 1),
        ),
      ],
    );

    var now = DateTime.utc(2026, 8, 2, 10);
    await SyncEngine.forTesting(
      localStore: deviceA,
      drive: drive,
      clock: () => now,
    ).sync();

    final deviceB = InMemorySyncLocalStore(deviceId: 'b');
    now = DateTime.utc(2026, 8, 2, 11);
    final result = await SyncEngine.forTesting(
      localStore: deviceB,
      drive: drive,
      clock: () => now,
    ).sync();

    expect(result.pulled, greaterThanOrEqualTo(1));
    expect(deviceB.transactions, hasLength(1));
    expect(deviceB.transactions.single.id, 't1');
  });

  test('idempotent sync pushes nothing when unchanged', () async {
    final drive = FakeDriveClient();
    final store = InMemorySyncLocalStore(
      deviceId: 'a',
      transactions: [
        MoneyTransaction(
          id: 't1',
          amount: 1,
          type: TransactionType.expense,
          category: 'Food',
          date: DateTime(2026, 7, 1),
        ),
      ],
    );

    var now = DateTime.utc(2026, 8, 2, 10);
    final engine = SyncEngine.forTesting(
      localStore: store,
      drive: drive,
      clock: () => now,
    );
    await engine.sync();
    final writesAfterFirst = drive.writeCount;

    now = DateTime.utc(2026, 8, 2, 11);
    final second = await engine.sync();
    expect(second.pushed, 0);
    // Manifest may still be rewritten; shard file writes should not grow much.
    expect(drive.writeCount, lessThanOrEqualTo(writesAfterFirst + 1));
  });
}
