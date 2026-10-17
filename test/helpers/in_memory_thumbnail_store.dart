import 'dart:io';
import 'dart:typed_data';

import 'package:loggym/data/services/thumbnail_store.dart';

/// Real file IO never completes under `testWidgets` fake async.
class InMemoryThumbnailStore implements ThumbnailStore {
  final saved = <String>[];
  final deleted = <String>[];

  @override
  File file(String relativePath) => File(relativePath);

  @override
  Future<String> save(String name, Uint8List bytes) async {
    saved.add(name);
    return 'thumbnails/$name';
  }

  @override
  Future<void> delete(String relativePath) async => deleted.add(relativePath);
}
