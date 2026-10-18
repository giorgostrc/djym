import 'dart:io';

import 'package:djym/data/database/app_database.dart';
import 'package:drift/drift.dart' show TableUpdate;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

class BackupInfo {
  const BackupInfo({
    required this.schemaVersion,
    required this.workoutCount,
    this.lastWorkoutAt,
  });

  final int schemaVersion;
  final int workoutCount;
  final DateTime? lastWorkoutAt;
}

/// A backup is a copy of the database file, photos included.
class BackupService {
  const BackupService({
    required this.workDirectory,
    required this.safetyDirectory,
  });

  final Directory workDirectory;

  /// Where the current data is copied before an import replaces it.
  final Directory safetyDirectory;

  /// `VACUUM INTO` takes a consistent copy while the app keeps running.
  Future<File> export(
    AppDatabase database, {
    required Directory destination,
  }) async {
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final backup = File('${destination.path}/djym-backup-$date.db');
    await destination.create(recursive: true);
    if (backup.existsSync()) await backup.delete();
    await database.customStatement('VACUUM INTO ?', [backup.path]);
    return backup;
  }

  /// Reads what a backup holds without touching the app's own data.
  BackupInfo inspect(File backup) {
    try {
      final database = sqlite3.open(backup.path, mode: OpenMode.readOnly);
      try {
        final version = database.select('PRAGMA user_version').single;
        final workouts = database
            .select(
              'SELECT count(*) AS count, max(started_at) AS last '
              'FROM workout_sessions WHERE finished_at IS NOT NULL',
            )
            .single;
        final last = workouts['last'] as String?;
        return BackupInfo(
          schemaVersion: version.columnAt(0) as int,
          workoutCount: workouts['count'] as int,
          lastWorkoutAt: last == null ? null : DateTime.parse(last).toLocal(),
        );
      } finally {
        database.dispose();
      }
    } on SqliteException {
      throw const FormatException('Not a djym backup');
    }
  }

  /// Replaces every row of [database] with the backup's, inside the open
  /// connection: no file swap, so live queries simply refresh. The backup is
  /// first upgraded on a copy, so backups from older versions restore too.
  Future<void> restore(AppDatabase database, File backup) async {
    final upgraded = await backup.copy('${workDirectory.path}/restore.sqlite');
    final copy = AppDatabase(NativeDatabase(upgraded));
    await copy.customSelect('SELECT 1').get();
    await copy.close();

    await database.customStatement('ATTACH DATABASE ? AS backup', [
      upgraded.path,
    ]);
    await database.customStatement('PRAGMA foreign_keys = OFF');
    try {
      await database.transaction(() async {
        for (final table in database.allTables) {
          final name = '"${table.actualTableName}"';
          final columns = [
            for (final column in table.$columns) '"${column.name}"',
          ].join(', ');
          await database.customStatement('DELETE FROM $name');
          await database.customStatement(
            'INSERT INTO $name ($columns) SELECT $columns FROM backup.$name',
          );
        }
      });
    } finally {
      await database.customStatement('PRAGMA foreign_keys = ON');
      await database.customStatement('DETACH DATABASE backup');
      await upgraded.delete();
    }
    database.notifyUpdates({
      for (final table in database.allTables) TableUpdate.onTable(table),
    });
  }
}

final backupServiceProvider = FutureProvider<BackupService>((ref) async {
  final support = await getApplicationSupportDirectory();
  return BackupService(
    workDirectory: await getTemporaryDirectory(),
    safetyDirectory: Directory('${support.path}/safety-copies'),
  );
});
