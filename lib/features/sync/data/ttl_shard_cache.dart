import 'dart:collection';

/// In-memory LRU-ish cache of shard bytes with unused TTL eviction.
///
/// Files remain on Drive; this only drops local copies after [ttl] without
/// [touch]/[put] activity.
class TtlShardCache {
  TtlShardCache({
    this.ttl = const Duration(days: 30),
    this.maxEntries = 256,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration ttl;
  final int maxEntries;
  final DateTime Function() _clock;

  final LinkedHashMap<String, _CacheEntry> _entries = LinkedHashMap();

  int get length => _entries.length;

  bool contains(String path) {
    _evictExpired();
    return _entries.containsKey(path);
  }

  List<int>? get(String path) {
    _evictExpired();
    final entry = _entries.remove(path);
    if (entry == null) return null;
    entry.lastAccess = _clock();
    _entries[path] = entry;
    return List<int>.from(entry.bytes);
  }

  void put(String path, List<int> bytes) {
    _evictExpired();
    _entries.remove(path);
    _entries[path] = _CacheEntry(
      bytes: List<int>.from(bytes),
      lastAccess: _clock(),
    );
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  void touch(String path) {
    final entry = _entries[path];
    if (entry == null) return;
    entry.lastAccess = _clock();
    _entries.remove(path);
    _entries[path] = entry;
  }

  void remove(String path) => _entries.remove(path);

  void clear() => _entries.clear();

  /// Evicts unused entries and returns removed paths.
  List<String> evictExpired() {
    final now = _clock();
    final removed = <String>[];
    final keys = _entries.keys.toList();
    for (final key in keys) {
      final entry = _entries[key]!;
      if (now.difference(entry.lastAccess) > ttl) {
        _entries.remove(key);
        removed.add(key);
      }
    }
    return removed;
  }

  void _evictExpired() => evictExpired();
}

class _CacheEntry {
  _CacheEntry({required this.bytes, required this.lastAccess});

  final List<int> bytes;
  DateTime lastAccess;
}
