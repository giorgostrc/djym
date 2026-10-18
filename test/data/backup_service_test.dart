import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:djym/data/database/app_database.dart';
import 'package:djym/data/repositories/exercise_repository.dart';
import 'package:djym/data/repositories/workout_session_repository.dart';
import 'package:djym/data/services/backup_service.dart';
import 'package:djym/domain/tracking_type.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late BackupService service;
  late File databaseFile;

  setUp(() {
    root = Directory.systemTemp.createTempSync('djym_backup');
    databaseFile = File('${root.path}/djym.sqlite');
    service = BackupService(
      workDirectory: Directory('${root.path}/work')..createSync(),
      safetyDirectory: Directory('${root.path}/safety'),
    );
  });

  tearDown(() => root.deleteSync(recursive: true));

  Future<File> exportWithOneWorkout() async {
    final database = AppDatabase(NativeDatabase(databaseFile));
    final squat = await ExerciseRepository(database).saveExercise(
      title: 'Squat',
      trackingType: TrackingType.weightReps,
      muscleIds: const [],
      thumbnail: Uint8List.fromList([1, 2, 3]),
    );
    final sessions = WorkoutSessionRepository(database);
    final id = await sessions.logPastSession(DateTime(2026, 10, 3));
    await sessions.addExercises(id, [squat]);

    final backup = await service.export(
      database,
      destination: Directory('${root.path}/out'),
    );
    await database.close();
    return backup;
  }

  test('exports a dated database that inspects as this schema', () async {
    final backup = await exportWithOneWorkout();

    final info = service.inspect(backup);

    expect(
      backup.path,
      matches(RegExp(r'djym-backup-\d{4}-\d{2}-\d{2}\.db$')),
    );
    expect(info.schemaVersion, AppDatabase.currentSchemaVersion);
    expect(info.workoutCount, 1);
    expect(info.lastWorkoutAt, DateTime(2026, 10, 3, 18));
  });

  test(
    'restoring replaces the open database and refreshes live queries',
    () async {
      final backup = await exportWithOneWorkout();
      final live = AppDatabase(NativeDatabase.memory());
      addTearDown(live.close);
      final exercises = ExerciseRepository(live);
      await exercises.saveExercise(
        title: 'Bench press',
        trackingType: TrackingType.weightReps,
        muscleIds: const [],
      );
      final titles = exercises.watchExercises().map(
        (list) => [for (final entry in list) entry.exercise.title],
      );
      final updates = StreamIterator(titles);
      await updates.moveNext();
      expect(updates.current, ['Bench press']);

      await service.restore(live, backup);

      await updates.moveNext();
      expect(updates.current, ['Squat']);
      final squat = await live.select(live.exercises).getSingle();
      expect(await exercises.thumbnail(squat.id), [1, 2, 3]);
      expect(await live.select(live.workoutSessions).get(), hasLength(1));
      await updates.cancel();
    },
  );

  test('rejects a file that is not a backup', () {
    final notBackup = File('${root.path}/notes.txt')..writeAsStringSync('hi');

    expect(() => service.inspect(notBackup), throwsFormatException);
  });
}
