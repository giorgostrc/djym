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
  const BackupService({required this.workDirectory});

  final Directory workDirectory;

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
  /// Nothing changes unless every row comes across with its links intact.
  Future<void> restore(AppDatabase database, File backup) async {
    final upgraded = await backup.copy('${workDirectory.path}/restore.sqlite');
    try {
      await _upgrade(upgraded);
      await _replaceRows(database, upgraded);
    } finally {
      await upgraded.delete();
    }
    database.notifyUpdates({
      for (final table in database.allTables) TableUpdate.onTable(table),
    });
  }

  /// Opening the copy as the app's database runs its migrations.
  Future<void> _upgrade(File copy) async {
    final database = AppDatabase(NativeDatabase(copy));
    try {
      await database.customSelect('SELECT 1').get();
    } finally {
      await database.close();
    }
  }

  /// Foreign keys are off while tables are emptied and refilled in any
  /// order, so they are checked before the transaction commits.
  Future<void> _replaceRows(AppDatabase database, File upgraded) async {
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
        final broken = await database
            .customSelect('PRAGMA main.foreign_key_check')
            .get();
        if (broken.isNotEmpty) {
          throw const FormatException('The backup has broken links');
        }
      });
    } finally {
      await database.customStatement('PRAGMA foreign_keys = ON');
      await database.customStatement('DETACH DATABASE backup');
    }
  }
}

final backupServiceProvider = FutureProvider<BackupService>(
  (ref) async => BackupService(workDirectory: await getTemporaryDirectory()),
);
