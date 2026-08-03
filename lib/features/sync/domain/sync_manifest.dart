/// Index of all Drive shards for StatMaxxer sync (v1).
class SyncManifest {
  const SyncManifest({
    required this.version,
    required this.deviceId,
    required this.lastSyncAt,
    required this.shards,
  });

  /// Manifest schema version (not app schema).
  final int version;
  final String deviceId;
  final DateTime lastSyncAt;
  final Map<String, SyncShardIndexEntry> shards;

  static const currentVersion = 1;

  factory SyncManifest.empty({
    required String deviceId,
    DateTime? lastSyncAt,
  }) {
    return SyncManifest(
      version: currentVersion,
      deviceId: deviceId,
      lastSyncAt: lastSyncAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      shards: const {},
    );
  }

  factory SyncManifest.fromJson(Map<String, dynamic> json) {
    final rawShards = json['shards'] as Map<String, dynamic>? ?? const {};
    return SyncManifest(
      version: (json['version'] as num?)?.toInt() ?? currentVersion,
      deviceId: json['deviceId'] as String? ?? '',
      lastSyncAt: DateTime.parse(
        json['lastSyncAt'] as String? ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toIso8601String(),
      ).toUtc(),
      shards: {
        for (final e in rawShards.entries)
          e.key: SyncShardIndexEntry.fromJson(
            Map<String, dynamic>.from(e.value as Map),
          ),
      },
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'deviceId': deviceId,
        'lastSyncAt': lastSyncAt.toUtc().toIso8601String(),
        'shards': {
          for (final e in shards.entries) e.key: e.value.toJson(),
        },
      };

  SyncManifest copyWith({
    int? version,
    String? deviceId,
    DateTime? lastSyncAt,
    Map<String, SyncShardIndexEntry>? shards,
  }) {
    return SyncManifest(
      version: version ?? this.version,
      deviceId: deviceId ?? this.deviceId,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      shards: shards ?? this.shards,
    );
  }
}

class SyncShardIndexEntry {
  const SyncShardIndexEntry({
    required this.path,
    required this.checksum,
    required this.updatedAt,
    this.etag,
  });

  final String path;
  final String checksum;
  final DateTime updatedAt;

  /// Drive file etag when known (optional).
  final String? etag;

  factory SyncShardIndexEntry.fromJson(Map<String, dynamic> json) {
    return SyncShardIndexEntry(
      path: json['path'] as String,
      checksum: json['checksum'] as String? ?? '',
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      etag: json['etag'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'checksum': checksum,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        if (etag != null) 'etag': etag,
      };

  SyncShardIndexEntry copyWith({
    String? path,
    String? checksum,
    DateTime? updatedAt,
    String? etag,
    bool clearEtag = false,
  }) {
    return SyncShardIndexEntry(
      path: path ?? this.path,
      checksum: checksum ?? this.checksum,
      updatedAt: updatedAt ?? this.updatedAt,
      etag: clearEtag ? null : (etag ?? this.etag),
    );
  }
}
