import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../domain/sync_manifest.dart';
import 'shard_paths.dart';

enum ShardKind {
  habitsMeta,
  settings,
  wishlist,
  money,
  occurrences,
  quantity,
}

/// On-wire shard envelope (JSON under appDataFolder).
class SyncShard {
  const SyncShard({
    required this.kind,
    required this.path,
    required this.updatedAt,
    required this.items,
    this.schemaVersion = SyncShard.currentSchemaVersion,
  });

  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final ShardKind kind;
  final String path;
  final DateTime updatedAt;

  /// Domain maps (already JSON-ready) for this shard.
  final List<Map<String, dynamic>> items;

  factory SyncShard.fromJson(Map<String, dynamic> json) {
    return SyncShard(
      schemaVersion:
          (json['schemaVersion'] as num?)?.toInt() ?? currentSchemaVersion,
      kind: ShardKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => _inferKind(json['path'] as String? ?? ''),
      ),
      path: json['path'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      items: (json['items'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'kind': kind.name,
        'path': path,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'items': items,
      };

  Uint8List encodeBytes() {
    final text = const JsonEncoder.withIndent('  ').convert(toJson());
    return Uint8List.fromList(utf8.encode(text));
  }

  static SyncShard decodeBytes(Uint8List bytes) {
    final map = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    return SyncShard.fromJson(map);
  }

  /// Stable checksum over kind/path/items (excludes updatedAt so clock skew
  /// alone does not change identity; LWW still uses updatedAt).
  String checksum() {
    final payload = jsonEncode({
      'kind': kind.name,
      'path': path,
      'items': items,
    });
    return sha256.convert(utf8.encode(payload)).toString();
  }

  SyncShardIndexEntry toIndexEntry({String? etag}) {
    return SyncShardIndexEntry(
      path: path,
      checksum: checksum(),
      updatedAt: updatedAt,
      etag: etag,
    );
  }

  static ShardKind _inferKind(String path) {
    if (path == ShardPaths.metaHabits) return ShardKind.habitsMeta;
    if (path == ShardPaths.metaSettings) return ShardKind.settings;
    if (path == ShardPaths.metaWishlist) return ShardKind.wishlist;
    if (ShardPaths.isMoney(path)) return ShardKind.money;
    if (ShardPaths.isOccurrences(path)) return ShardKind.occurrences;
    if (ShardPaths.isQuantity(path)) return ShardKind.quantity;
    return ShardKind.money;
  }
}

class ManifestCodec {
  static Uint8List encode(SyncManifest manifest) {
    final text = const JsonEncoder.withIndent('  ').convert(manifest.toJson());
    return Uint8List.fromList(utf8.encode(text));
  }

  static SyncManifest decode(Uint8List bytes) {
    final map = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    return SyncManifest.fromJson(map);
  }
}
