import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

const int _maxBytes = 256 * 1024;

/// Errors nothing else handled, kept on the phone so they can be shared.
/// Starts over once it grows past [_maxBytes].
class ErrorLog {
  const ErrorLog(this.file);

  final File file;

  bool get hasEntries => file.existsSync();

  /// Synchronous, so an entry is written even if the app is going down.
  void record(Object error, StackTrace? stack) {
    if (hasEntries && file.lengthSync() > _maxBytes) file.deleteSync();
    file.writeAsStringSync(
      '${DateTime.now().toIso8601String()} $error\n$stack\n\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  void clear() {
    if (hasEntries) file.deleteSync();
  }
}

final errorLogProvider = FutureProvider<ErrorLog>((ref) async {
  final support = await getApplicationSupportDirectory();
  return ErrorLog(File('${support.path}/errors.log'));
});
