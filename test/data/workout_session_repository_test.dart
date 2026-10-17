import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loggym/data/database/app_database.dart';
import 'package:loggym/data/repositories/exercise_repository.dart';
import 'package:loggym/data/repositories/workout_session_repository.dart';
import 'package:loggym/domain/tracking_type.dart';

void main() {
  late AppDatabase database;
  late WorkoutSessionRepository sessions;
  late ExerciseRepository exercises;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    sessions = WorkoutSessionRepository(database);
    exercises = ExerciseRepository(database);
  });

  tearDown(() => database.close());

  Future<int> createExercise(String title, TrackingType type) =>
      exercises.saveExercise(
        title: title,
        trackingType: type,
        muscleIds: const [],
      );

  Future<List<SessionExercise>> sessionExercises(int sessionId) =>
      sessions.watchSessionExercises(sessionId).first;

  Future<void> logSet(
    ExerciseSet set, {
    int? reps,
    double? weightKg,
    int? durationSeconds,
    double? distanceMeters,
  }) => sessions.updateSet(
    set.id,
    ExerciseSetsCompanion(
      reps: Value(reps),
      weightKg: Value(weightKg),
      durationSeconds: Value(durationSeconds),
      distanceMeters: Value(distanceMeters),
    ),
  );

  test('starting twice returns the same active session', () async {
    final first = await sessions.startSession();
    final second = await sessions.startSession();

    expect(second, first);
    expect((await sessions.watchActiveSession().first)?.id, first);
  });

  test('adds exercises with one empty set each, in order', () async {
    final squat = await createExercise('Squat', TrackingType.weightReps);
    final plank = await createExercise('Plank', TrackingType.duration);
    final sessionId = await sessions.startSession();

    await sessions.addExercises(sessionId, [plank, squat]);
    await sessions.addSet(sessionId, plank);

    final [first, second] = await sessionExercises(sessionId);
    expect(first.exercise.title, 'Plank');
    expect(first.sets, hasLength(2));
    expect(second.exercise.title, 'Squat');
    expect(second.sets, hasLength(1));
  });

  test('reorders exercises and keeps the set order inside each', () async {
    final squat = await createExercise('Squat', TrackingType.weightReps);
    final plank = await createExercise('Plank', TrackingType.duration);
    final sessionId = await sessions.startSession();
    await sessions.addExercises(sessionId, [squat, plank]);
    await sessions.addSet(sessionId, squat);
    final [squatEntry, plankEntry] = await sessionExercises(sessionId);

    await sessions.reorderExercises([plankEntry, squatEntry]);

    final [first, second] = await sessionExercises(sessionId);
    expect(first.exercise.title, 'Plank');
    expect(second.sets.map((set) => set.id), squatEntry.sets.map((s) => s.id));
  });

  test('deleted sets come back on restore', () async {
    final squat = await createExercise('Squat', TrackingType.weightReps);
    final sessionId = await sessions.startSession();
    await sessions.addExercises(sessionId, [squat]);
    final [entry] = await sessionExercises(sessionId);
    await logSet(entry.sets.single, reps: 5, weightKg: 100);
    final [logged] = await sessionExercises(sessionId);

    await sessions.deleteSets(logged.sets);
    expect(await sessionExercises(sessionId), isEmpty);

    await sessions.restoreSets(logged.sets);
    final [restored] = await sessionExercises(sessionId);
    expect(restored.sets.single.weightKg, 100);
  });

  test('finishing drops empty sets and summarises the workout', () async {
    final squat = await createExercise('Squat', TrackingType.weightReps);
    final plank = await createExercise('Plank', TrackingType.duration);
    final sessionId = await sessions.startSession();
    await sessions.addExercises(sessionId, [squat, plank]);
    await sessions.addSet(sessionId, squat);
    await sessions.addSet(sessionId, squat);
    final [squatEntry, plankEntry] = await sessionExercises(sessionId);
    await logSet(squatEntry.sets[0], reps: 5, weightKg: 100);
    await logSet(squatEntry.sets[1], reps: 3, weightKg: 110);
    await logSet(plankEntry.sets.single, durationSeconds: 60);

    final summary = await sessions.finishSession(sessionId);

    expect(summary.exerciseCount, 2);
    expect(summary.setCount, 3);
    expect(summary.volumeKg, 830);
    expect(await sessions.watchActiveSession().first, isNull);
    final [squatAfter, _] = await sessionExercises(sessionId);
    expect(squatAfter.sets, hasLength(2));
  });

  test('discarding removes the session and its sets', () async {
    final squat = await createExercise('Squat', TrackingType.weightReps);
    final sessionId = await sessions.startSession();
    await sessions.addExercises(sessionId, [squat]);

    await sessions.discardSession(sessionId);

    expect(await sessions.watchActiveSession().first, isNull);
    expect(await database.select(database.exerciseSets).get(), isEmpty);
  });

  group('records', () {
    Future<void> finishedSession(
      int exerciseId,
      List<({int? reps, double? weightKg, double? distanceMeters})> sets,
    ) async {
      final sessionId = await sessions.startSession();
      for (final _ in sets) {
        await sessions.addSet(sessionId, exerciseId);
      }
      final [entry] = await sessionExercises(sessionId);
      for (final (index, values) in sets.indexed) {
        await logSet(
          entry.sets[index],
          reps: values.reps,
          weightKg: values.weightKg,
          distanceMeters: values.distanceMeters,
        );
      }
      await sessions.finishSession(sessionId);
    }

    test('weight × reps: heaviest set wins, more reps break ties', () async {
      final id = await createExercise('Squat', TrackingType.weightReps);
      final exercise = await (database.select(
        database.exercises,
      )..where((e) => e.id.equals(id))).getSingle();
      await finishedSession(id, [
        (reps: 5, weightKg: 120, distanceMeters: null),
        (reps: 8, weightKg: 100, distanceMeters: null),
      ]);
      await finishedSession(id, [
        (reps: 3, weightKg: 100, distanceMeters: null),
        (reps: 6, weightKg: 100, distanceMeters: null),
      ]);
      final current = await sessions.startSession();

      final records = await sessions.exerciseRecords(
        exercise: exercise,
        excludingSessionId: current,
      );

      expect(records.allTimeBest?.weightKg, 120);
      expect(records.lastPerformance?.sets.map((set) => set.reps), [3, 6]);
    });

    test('distance + time: the longest distance wins', () async {
      final id = await createExercise('Run', TrackingType.distanceDuration);
      final exercise = await (database.select(
        database.exercises,
      )..where((e) => e.id.equals(id))).getSingle();
      await finishedSession(id, [
        (reps: null, weightKg: null, distanceMeters: 5000),
        (reps: null, weightKg: null, distanceMeters: 8000),
      ]);
      final current = await sessions.startSession();

      final records = await sessions.exerciseRecords(
        exercise: exercise,
        excludingSessionId: current,
      );

      expect(records.allTimeBest?.distanceMeters, 8000);
    });

    test('an exercise never logged has no records', () async {
      final id = await createExercise('Squat', TrackingType.weightReps);
      final exercise = await (database.select(
        database.exercises,
      )..where((e) => e.id.equals(id))).getSingle();

      final records = await sessions.exerciseRecords(
        exercise: exercise,
        excludingSessionId: await sessions.startSession(),
      );

      expect(records.allTimeBest, isNull);
      expect(records.lastPerformance, isNull);
    });
  });
}
