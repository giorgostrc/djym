import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loggym/data/database/app_database.dart';
import 'package:path_provider/path_provider.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase(
    driftDatabase(name: 'loggym'),
    legacyFilesDirectory: getApplicationSupportDirectory,
  );
  ref.onDispose(database.close);
  return database;
});
