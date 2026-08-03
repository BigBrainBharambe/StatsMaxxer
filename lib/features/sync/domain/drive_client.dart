import 'dart:typed_data';

/// Abstraction over Google Drive appDataFolder (or a fake for tests).
abstract class DriveClient {
  /// Reads a file by relative path under the sync root. Null if missing.
  Future<DriveFile?> readFile(String path);

  /// Creates or replaces [path] with [bytes]. Returns etag when available.
  Future<DriveWriteResult> writeFile(
    String path,
    Uint8List bytes, {
    String contentType = 'application/json',
  });

  /// Deletes [path] if present. No-op when missing.
  Future<void> deleteFile(String path);

  /// Lists relative paths under optional [prefix] (e.g. `money/`).
  Future<List<String>> listFiles({String? prefix});
}

class DriveFile {
  const DriveFile({
    required this.path,
    required this.bytes,
    this.etag,
    this.modifiedTime,
  });

  final String path;
  final Uint8List bytes;
  final String? etag;
  final DateTime? modifiedTime;
}

class DriveWriteResult {
  const DriveWriteResult({this.etag, this.modifiedTime});

  final String? etag;
  final DateTime? modifiedTime;
}
