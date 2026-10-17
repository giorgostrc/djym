import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loggym/data/database/app_database.dart';
import 'package:loggym/data/repositories/exercise_repository.dart';
import 'package:loggym/domain/tracking_type.dart';

void main() {
  late AppDatabase database;
  late ExerciseRepository repository;
  late Map<String, int> muscleIds;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = ExerciseRepository(database);
    final muscles = await repository.watchMuscles().first;
    muscleIds = {for (final muscle in muscles) muscle.name: muscle.id};
  });

  tearDown(() => database.close());

  Future<int> saveSquat() => repository.saveExercise(
    title: 'Squat',
    trackingType: TrackingType.weightReps,
    muscleIds: [muscleIds['Quads']!, muscleIds['Glutes']!],
  );

  Future<List<String>> exerciseTitles() async => [
    for (final entry in await repository.watchExercises().first)
      entry.exercise.title,
  ];

  test('seeds the muscle list on creation', () async {
    expect(muscleIds, hasLength(14));
  });

  test('saves an exercise with its muscles in tap order', () async {
    await saveSquat();

    final [squat] = await repository.watchExercises().first;

    expect(squat.exercise.trackingType, TrackingType.weightReps);
    expect(squat.muscles.map((muscle) => muscle.name), ['Quads', 'Glutes']);
  });

  test('updates an exercise and replaces its muscles', () async {
    final id = await saveSquat();

    await repository.saveExercise(
      id: id,
      title: 'Front squat',
      trackingType: TrackingType.reps,
      formGuidance: 'Elbows high',
      muscleIds: [muscleIds['Abs']!],
    );

    final [squat] = await repository.watchExercises().first;

    expect(squat.exercise.id, id);
    expect(squat.exercise.title, 'Front squat');
    expect(squat.exercise.trackingType, TrackingType.reps);
    expect(squat.exercise.formGuidance, 'Elbows high');
    expect(squat.muscles.map((muscle) => muscle.name), ['Abs']);
  });

  test('lists exercises alphabetically, ignoring case', () async {
    for (final title in ['row', 'Bench press', 'Deadlift']) {
      await repository.saveExercise(
        title: title,
        trackingType: TrackingType.weightReps,
        muscleIds: const [],
      );
    }

    expect(await exerciseTitles(), ['Bench press', 'Deadlift', 'row']);
  });

  test('deletes an unused exercise and restores it on undo', () async {
    await saveSquat();
    final [squat] = await repository.watchExercises().first;

    expect(
      await repository.removeExercise(squat.exercise.id),
      ExerciseRemoval.deleted,
    );
    expect(await exerciseTitles(), isEmpty);

    await repository.restoreExercise(squat);
    final [restored] = await repository.watchExercises().first;

    expect(restored.exercise.id, squat.exercise.id);
    expect(restored.muscles.map((muscle) => muscle.name), ['Quads', 'Glutes']);
  });

  test(
    'archives an exercise used in a session and restores it on undo',
    () async {
      await saveSquat();
      final [squat] = await repository.watchExercises().first;
      final sessionId = await database
          .into(database.workoutSessions)
          .insert(WorkoutSessionsCompanion.insert(startedAt: DateTime(2026)));
      await database
          .into(database.exerciseSets)
          .insert(
            ExerciseSetsCompanion.insert(
              sessionId: sessionId,
              exerciseId: squat.exercise.id,
              position: 0,
            ),
          );

      expect(
        await repository.removeExercise(squat.exercise.id),
        ExerciseRemoval.archived,
      );
      expect(await exerciseTitles(), isEmpty);
      expect(await database.select(database.exercises).get(), hasLength(1));

      await repository.restoreExercise(squat);

      expect(await exerciseTitles(), ['Squat']);
    },
  );

  test('keeps the wger link on edit and can remove the thumbnail', () async {
    await repository.saveExercise(
      title: 'Bench Press',
      trackingType: TrackingType.weightReps,
      muscleIds: [muscleIds['Chest']!],
      externalId: 'wger:bench-uuid',
      thumbnail: Uint8List.fromList([1, 2, 3]),
    );
    final [bench] = await repository.watchExercises().first;

    await repository.saveExercise(
      id: bench.exercise.id,
      title: 'Bench press',
      trackingType: TrackingType.weightReps,
      muscleIds: [muscleIds['Chest']!],
    );
    final [edited] = await repository.watchExercises().first;

    expect(edited.exercise.title, 'Bench press');
    expect(edited.exercise.externalId, 'wger:bench-uuid');
    expect(await repository.thumbnail(edited.exercise.id), isNull);
  });

  test('saving an archived wger exercise again restores it', () async {
    Future<int> saveBench() => repository.saveExercise(
      title: 'Bench Press',
      trackingType: TrackingType.weightReps,
      muscleIds: [muscleIds['Chest']!],
      externalId: 'wger:bench-uuid',
    );
    final id = await saveBench();
    await database
        .into(database.planExercises)
        .insert(
          PlanExercisesCompanion.insert(
            planId: await database
                .into(database.workoutPlans)
                .insert(WorkoutPlansCompanion.insert(name: 'Push')),
            exerciseId: id,
            position: 0,
            targetSets: 3,
          ),
        );
    await repository.removeExercise(id);

    expect(await saveBench(), id);
    expect(await exerciseTitles(), ['Bench Press']);
  });

  test('deleting drops the photo and undo puts it back', () async {
    final id = await repository.saveExercise(
      title: 'Squat',
      trackingType: TrackingType.weightReps,
      muscleIds: const [],
      thumbnail: Uint8List.fromList([1, 2, 3]),
    );
    final [squat] = await repository.watchExercises().first;
    final photo = await repository.thumbnail(id);

    await repository.removeExercise(id);
    expect(await database.select(database.exerciseThumbnails).get(), isEmpty);

    await repository.restoreExercise(squat, thumbnail: photo);
    expect(await repository.thumbnail(id), [1, 2, 3]);
  });
}
