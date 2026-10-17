import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Stores exercise thumbnails under app storage. Paths saved in the database
/// are relative, so they survive a backup restored on another install.
class ThumbnailStore {
  const ThumbnailStore(this._directory);

  final Directory _directory;

  File file(String relativePath) => File('${_directory.path}/$relativePath');

  Future<String> save(String name, Uint8List bytes) async {
    final relativePath = 'thumbnails/$name';
    final target = await file(relativePath).create(recursive: true);
    await target.writeAsBytes(bytes);
    return relativePath;
  }

  Future<void> delete(String relativePath) async {
    final target = file(relativePath);
    if (target.existsSync()) await target.delete();
  }
}

final thumbnailStoreProvider = FutureProvider<ThumbnailStore>(
  (ref) async => ThumbnailStore(await getApplicationSupportDirectory()),
);
