import 'dart:typed_data';

import '../domain/drive_client.dart';

/// In-memory Drive for tests and dry-run without OAuth.
class FakeDriveClient implements DriveClient {
  final Map<String, DriveFile> _files = {};

  Map<String, DriveFile> get files => Map.unmodifiable(_files);

  int writeCount = 0;
  int readCount = 0;

  @override
  Future<DriveFile?> readFile(String path) async {
    readCount++;
    return _files[path];
  }

  @override
  Future<DriveWriteResult> writeFile(
    String path,
    Uint8List bytes, {
    String contentType = 'application/json',
  }) async {
    writeCount++;
    final etag = 'etag-${writeCount}-${bytes.length}';
    final modified = DateTime.now().toUtc();
    _files[path] = DriveFile(
      path: path,
      bytes: Uint8List.fromList(bytes),
      etag: etag,
      modifiedTime: modified,
    );
    return DriveWriteResult(etag: etag, modifiedTime: modified);
  }

  @override
  Future<void> deleteFile(String path) async {
    _files.remove(path);
  }

  @override
  Future<List<String>> listFiles({String? prefix}) async {
    final keys = _files.keys.toList()..sort();
    if (prefix == null || prefix.isEmpty) return keys;
    return keys.where((k) => k.startsWith(prefix)).toList();
  }

  void seed(String path, Uint8List bytes, {String? etag}) {
    _files[path] = DriveFile(
      path: path,
      bytes: Uint8List.fromList(bytes),
      etag: etag ?? 'seed',
      modifiedTime: DateTime.now().toUtc(),
    );
  }
}
