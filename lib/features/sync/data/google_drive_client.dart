import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:googleapis/drive/v3.dart' as drive;

import '../domain/drive_client.dart';

/// Google Drive appDataFolder adapter.
///
/// Requires a valid OAuth access token with `drive.appdata` scope.
class GoogleDriveClient implements DriveClient {
  GoogleDriveClient({
    required String accessToken,
    http.Client? httpClient,
  }) : _api = drive.DriveApi(
          _BearerClient(accessToken, httpClient ?? http.Client()),
        );

  final drive.DriveApi _api;

  /// App-owned folder id for create parents.
  static const appDataFolder = 'appDataFolder';

  @override
  Future<DriveFile?> readFile(String path) async {
    final meta = await _findByPath(path);
    if (meta == null || meta.id == null) return null;

    final media = await _api.files.get(
      meta.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = await _readMedia(media);
    return DriveFile(
      path: path,
      bytes: bytes,
      etag: meta.md5Checksum ?? meta.headRevisionId,
      modifiedTime: meta.modifiedTime,
    );
  }

  @override
  Future<DriveWriteResult> writeFile(
    String path,
    Uint8List bytes, {
    String contentType = 'application/json',
  }) async {
    final existing = await _findByPath(path);
    final media = drive.Media(
      Stream<List<int>>.value(bytes),
      bytes.length,
      contentType: contentType,
    );

    final meta = drive.File()
      ..name = _fileName(path)
      ..appProperties = {'path': path};

    late drive.File result;
    if (existing?.id != null) {
      result = await _api.files.update(
        meta,
        existing!.id!,
        uploadMedia: media,
      );
    } else {
      meta.parents = await _ensureParentFolders(path);
      result = await _api.files.create(
        meta,
        uploadMedia: media,
      );
    }

    return DriveWriteResult(
      etag: result.md5Checksum ?? result.headRevisionId,
      modifiedTime: result.modifiedTime,
    );
  }

  @override
  Future<void> deleteFile(String path) async {
    final meta = await _findByPath(path);
    if (meta?.id == null) return;
    await _api.files.delete(meta!.id!);
  }

  @override
  Future<List<String>> listFiles({String? prefix}) async {
    final out = <String>[];
    String? pageToken;
    do {
      final page = await _api.files.list(
        spaces: appDataFolder,
        corpora: 'user',
        pageSize: 100,
        pageToken: pageToken,
        $fields: 'nextPageToken, files(id, name, parents, appProperties)',
        q: "trashed = false",
      );
      for (final f in page.files ?? const <drive.File>[]) {
        final rel = f.appProperties?['path'] ?? f.name;
        if (rel == null) continue;
        if (prefix == null || rel.startsWith(prefix)) {
          out.add(rel);
        }
      }
      pageToken = page.nextPageToken;
    } while (pageToken != null);
    out.sort();
    return out;
  }

  Future<drive.File?> _findByPath(String path) async {
    // Prefer appProperties.path exact match; fall back to flat name for
    // shallow files like manifest.json.
    final escaped = path.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
    final q =
        "appProperties has { key='path' and value='$escaped' } and trashed = false";
    final listed = await _api.files.list(
      spaces: appDataFolder,
      corpora: 'user',
      pageSize: 1,
      q: q,
      $fields: 'files(id, name, md5Checksum, headRevisionId, modifiedTime, appProperties)',
    );
    if (listed.files != null && listed.files!.isNotEmpty) {
      return listed.files!.first;
    }

    // Flat lookup by leaf name under appDataFolder (legacy / simple layout).
    final name = _fileName(path);
    final byName = await _api.files.list(
      spaces: appDataFolder,
      corpora: 'user',
      pageSize: 10,
      q: "name = '${name.replaceAll("'", r"\'")}' and trashed = false",
      $fields: 'files(id, name, md5Checksum, headRevisionId, modifiedTime, appProperties, parents)',
    );
    for (final f in byName.files ?? const <drive.File>[]) {
      final stored = f.appProperties?['path'];
      if (stored == path || (stored == null && name == path)) {
        return f;
      }
    }
    return null;
  }

  /// Creates nested folders as needed; stores relative path on the file via
  /// appProperties so lookups don't depend on folder traversal alone.
  Future<List<String>> _ensureParentFolders(String path) async {
    // For MVP we store all files directly in appDataFolder and encode the
    // logical path in appProperties + a sanitized name.
    return const [appDataFolder];
  }

  String _fileName(String path) {
    // Drive name cannot contain `/`; encode path as flat name.
    return path.replaceAll('/', '__');
  }

  Future<Uint8List> _readMedia(drive.Media media) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in media.stream) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }
}

/// HTTP client that injects a Bearer access token.
class _BearerClient extends http.BaseClient {
  _BearerClient(this._token, this._inner);

  final String _token;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_token';
    return _inner.send(request);
  }
}

/// Encodes JSON helpers used by dry-run tooling.
String driveDebugJson(Object value) =>
    const JsonEncoder.withIndent('  ').convert(value);
