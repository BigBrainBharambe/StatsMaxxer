import 'package:flutter_test/flutter_test.dart';
import 'package:stat_maxxer/features/sync/data/ttl_shard_cache.dart';

void main() {
  test('get returns bytes and refreshes access time', () {
    var now = DateTime.utc(2026, 8, 1);
    final cache = TtlShardCache(
      ttl: const Duration(days: 2),
      clock: () => now,
    );
    cache.put('money/2026/07.json', [1, 2, 3]);
    expect(cache.get('money/2026/07.json'), [1, 2, 3]);

    now = DateTime.utc(2026, 8, 2);
    cache.touch('money/2026/07.json');
    now = DateTime.utc(2026, 8, 3, 12);
    expect(cache.contains('money/2026/07.json'), isTrue);
  });

  test('evicts unused shards after TTL', () {
    var now = DateTime.utc(2026, 8, 1);
    final cache = TtlShardCache(
      ttl: const Duration(days: 7),
      clock: () => now,
    );
    cache.put('a', [1]);
    cache.put('b', [2]);

    now = DateTime.utc(2026, 8, 5);
    cache.touch('a');

    now = DateTime.utc(2026, 8, 10);
    final removed = cache.evictExpired();
    expect(removed, ['b']);
    expect(cache.contains('a'), isTrue);
    expect(cache.contains('b'), isFalse);
  });

  test('evicts oldest when over maxEntries', () {
    final cache = TtlShardCache(maxEntries: 2);
    cache.put('1', [1]);
    cache.put('2', [2]);
    cache.put('3', [3]);
    expect(cache.length, 2);
    expect(cache.contains('1'), isFalse);
    expect(cache.contains('2'), isTrue);
    expect(cache.contains('3'), isTrue);
  });
}
