import '../domain/drive_client.dart';
import '../domain/sync_local_store.dart';
import '../domain/sync_manifest.dart';
import '../domain/sync_status.dart';
import 'fake_drive_client.dart';
import 'local_shard_index.dart';
import 'parallel_pool.dart';
import 'shard_builder.dart';
import 'shard_codec.dart';
import 'shard_paths.dart';
import 'ttl_shard_cache.dart';

/// Orchestrates local ↔ Drive shard sync (LWW per shard, bounded parallelism).
class SyncEngine {
  SyncEngine({
    required this.localStore,
    required DriveClient drive,
    ShardBuilder? builder,
    ShardConflictResolver? resolver,
    TtlShardCache? cache,
    this.concurrency = 4,
    DateTime Function()? clock,
  })  : _drive = drive,
        _builder = builder ?? const ShardBuilder(),
        _resolver = resolver ?? const ShardConflictResolver(),
        _cache = cache ?? TtlShardCache(),
        _clock = clock ?? (() => DateTime.now().toUtc());

  final SyncLocalStore localStore;
  final DriveClient _drive;
  final ShardBuilder _builder;
  final ShardConflictResolver _resolver;
  final TtlShardCache _cache;
  final int concurrency;
  final DateTime Function() _clock;

  TtlShardCache get cache => _cache;

  /// Dry-run / unit helper: sync against an in-memory Drive.
  static SyncEngine forTesting({
    required SyncLocalStore localStore,
    FakeDriveClient? drive,
    TtlShardCache? cache,
    int concurrency = 4,
    DateTime Function()? clock,
  }) {
    return SyncEngine(
      localStore: localStore,
      drive: drive ?? FakeDriveClient(),
      cache: cache,
      concurrency: concurrency,
      clock: clock,
    );
  }

  Future<SyncResult> sync() async {
    final now = _clock().toUtc();
    final deviceId = await localStore.getOrCreateDeviceId();
    final localIndex =
        LocalShardIndex.decode(await localStore.getLocalShardIndexJson());

    final snapshot = await localStore.loadSnapshot();
    final stamped = localIndex.stamp(
      _builder.build(snapshot, updatedAt: now),
      now: now,
    );
    final localByPath = {for (final s in stamped) s.path: s};

    final remoteManifest = await _readManifest();
    final plan = _resolver.plan(
      localByPath: localByPath,
      remoteIndex: remoteManifest.shards,
    );

    final pulledShards = await runBoundedParallel(
      plan.toPull.map((path) => () => _pullShard(path)),
      concurrency: concurrency,
    );

    if (pulledShards.isNotEmpty) {
      await localStore.applyShards(pulledShards);
      for (final s in pulledShards) {
        localIndex.upsert(s);
      }
    }

    // Rebuild after apply; preserve updatedAt for unchanged checksums.
    final mergedSnapshot = await localStore.loadSnapshot();
    final mergedStamped = localIndex.stamp(
      _builder.build(mergedSnapshot, updatedAt: now),
      now: now,
    );
    final mergedByPath = {for (final s in mergedStamped) s.path: s};

    final remoteAfterPull = <String, SyncShardIndexEntry>{
      ...remoteManifest.shards,
      for (final s in pulledShards) s.path: s.toIndexEntry(),
    };

    final pushPlan = _resolver.plan(
      localByPath: mergedByPath,
      remoteIndex: remoteAfterPull,
    );

    final pushedPaths = await runBoundedParallel(
      pushPlan.toPush.map((path) {
        return () async {
          final shard = mergedByPath[path];
          if (shard == null) return path;
          final result = await _drive.writeFile(path, shard.encodeBytes());
          _cache.put(path, shard.encodeBytes());
          localIndex.upsert(shard, etag: result.etag);
          return path;
        };
      }),
      concurrency: concurrency,
    );

    final index = <String, SyncShardIndexEntry>{
      ...remoteAfterPull,
    };
    for (final path in pushedPaths) {
      final shard = mergedByPath[path];
      if (shard == null) continue;
      index[path] = localIndex.entries[path] ?? shard.toIndexEntry();
    }

    // Keep index aligned with merged local shards we still have.
    for (final s in mergedStamped) {
      index.putIfAbsent(s.path, () => s.toIndexEntry());
      localIndex.upsert(s, etag: index[s.path]?.etag);
    }

    final newManifest = SyncManifest(
      version: SyncManifest.currentVersion,
      deviceId: deviceId,
      lastSyncAt: now,
      shards: index,
    );
    await _drive.writeFile(
      ShardPaths.manifest,
      ManifestCodec.encode(newManifest),
    );
    await localStore.setLastSyncedAt(now);
    await localStore.setLocalShardIndexJson(localIndex.encode());
    _cache.evictExpired();

    return SyncResult(
      pulled: pulledShards.length,
      pushed: pushedPaths.length,
      skipped: pushPlan.unchanged.length,
      finishedAt: now,
    );
  }

  Future<SyncManifest> _readManifest() async {
    final file = await _drive.readFile(ShardPaths.manifest);
    if (file == null) {
      return SyncManifest.empty(deviceId: '');
    }
    _cache.put(ShardPaths.manifest, file.bytes);
    return ManifestCodec.decode(file.bytes);
  }

  Future<SyncShard> _pullShard(String path) async {
    final file = await _drive.readFile(path);
    if (file == null) {
      throw StateError('Missing remote shard: $path');
    }
    _cache.put(path, file.bytes);
    return SyncShard.decodeBytes(file.bytes);
  }
}
