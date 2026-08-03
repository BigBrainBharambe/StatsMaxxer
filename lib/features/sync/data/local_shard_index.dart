import 'dart:convert';

import '../domain/sync_manifest.dart';
import 'shard_codec.dart';

/// Remembers last-known local shard checksums/updatedAt after a successful sync.
///
/// Used so only content that changed since the last sync gets a fresh
/// [updatedAt] (avoids force-pushing every shard after a pull).
class LocalShardIndex {
  LocalShardIndex([Map<String, SyncShardIndexEntry>? entries])
      : _entries = Map.of(entries ?? const {});

  final Map<String, SyncShardIndexEntry> _entries;

  Map<String, SyncShardIndexEntry> get entries =>
      Map.unmodifiable(_entries);

  factory LocalShardIndex.fromJson(Map<String, dynamic> json) {
    final raw = json['shards'] as Map<String, dynamic>? ?? const {};
    return LocalShardIndex({
      for (final e in raw.entries)
        e.key: SyncShardIndexEntry.fromJson(
          Map<String, dynamic>.from(e.value as Map),
        ),
    });
  }

  Map<String, dynamic> toJson() => {
        'shards': {for (final e in _entries.entries) e.key: e.value.toJson()},
      };

  static LocalShardIndex decode(String? raw) {
    if (raw == null || raw.isEmpty) return LocalShardIndex();
    try {
      return LocalShardIndex.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return LocalShardIndex();
    }
  }

  String encode() => jsonEncode(toJson());

  /// Stamps [candidates] with preserved updatedAt when checksum unchanged.
  List<SyncShard> stamp(
    List<SyncShard> candidates, {
    required DateTime now,
  }) {
    return [
      for (final shard in candidates)
        _stampOne(shard, now: now),
    ];
  }

  SyncShard _stampOne(SyncShard shard, {required DateTime now}) {
    final checksum = shard.checksum();
    final prev = _entries[shard.path];
    if (prev != null && prev.checksum == checksum) {
      return SyncShard(
        schemaVersion: shard.schemaVersion,
        kind: shard.kind,
        path: shard.path,
        updatedAt: prev.updatedAt,
        items: shard.items,
      );
    }
    return SyncShard(
      schemaVersion: shard.schemaVersion,
      kind: shard.kind,
      path: shard.path,
      updatedAt: now,
      items: shard.items,
    );
  }

  void replaceWith(Iterable<SyncShard> shards, {String? Function(String path)? etagOf}) {
    _entries
      ..clear()
      ..addAll({
        for (final s in shards)
          s.path: s.toIndexEntry(etag: etagOf?.call(s.path)),
      });
  }

  void upsert(SyncShard shard, {String? etag}) {
    _entries[shard.path] = shard.toIndexEntry(etag: etag);
  }
}
