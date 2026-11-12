import 'dart:io';

import 'package:djym/data/services/error_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late ErrorLog log;

  setUp(() {
    root = Directory.systemTemp.createTempSync('djym_errors');
    log = ErrorLog(File('${root.path}/errors.log'));
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('records errors with their stack and can be cleared', () {
    expect(log.hasEntries, isFalse);

    log.record(StateError('broken'), StackTrace.fromString('at main'));

    expect(log.file.readAsStringSync(), contains('Bad state: broken\nat main'));
    log.clear();
    expect(log.hasEntries, isFalse);
  });

  test('starts over once it grows too large', () {
    final big = 'x' * 300 * 1024;
    log
      ..record(big, null)
      ..record('latest', null);

    expect(log.file.readAsStringSync(), isNot(contains(big)));
    expect(log.file.readAsStringSync(), contains('latest'));
  });
}
