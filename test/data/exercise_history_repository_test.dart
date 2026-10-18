import 'package:djym/data/database/app_database.dart';
import 'package:djym/data/repositories/exercise_history_repository.dart';
import 'package:djym/data/repositories/exercise_repository.dart';
import 'package:djym/data/repositories/workout_session_repository.dart';
import 'package:djym/domain/tracking_type.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late WorkoutSessionRepository sessions;
  late ExerciseHistoryRepository history;
  late int squat;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    sessions = WorkoutSessionRepository(database);
    history = ExerciseHistoryRepository(database);
    squat = await ExerciseRepository(database).saveExercise(
      title: 'Squat',
      trackingType: TrackingType.weightReps,
      muscleIds: const [],
    );
  });

  tearDown(() => database.close());

  Future<int> logSquats(DateTime day, List<(double, int)> sets) async {
    final id = await sessions.logPastSession(day);
    for (final _ in sets) {
      await sessions.addSet(id, squat);
    }
    final rows = await (database.select(
      database.exerciseSets,
    )..where((set) => set.sessionId.equals(id))).get();
    for (final (index, (weight, reps)) in sets.indexed) {
      await sessions.updateSet(
        rows[index].id,
        ExerciseSetsCompanion(weightKg: Value(weight), reps: Value(reps)),
      );
    }
    return id;
  }

  test('lists workouts newest first with their best set', () async {
    await logSquats(DateTime(2026, 9, 2), [(80, 8), (90, 5)]);
    await logSquats(DateTime(2026, 9, 8), [(85, 8)]);

    final result = await history.watchHistory(squat).first;

    expect(result.workouts.map((w) => w.session.startedAt.day), [8, 2]);
    expect(result.workouts.last.best.weightKg, 90);
    expect(result.bestWorkout!.session.startedAt.day, 2);
  });

  test('marks workouts that beat every earlier best', () async {
    await logSquats(DateTime(2026, 9, 2), [(80, 5)]);
    final heavier = await logSquats(DateTime(2026, 9, 8), [(85, 5)]);
    await logSquats(DateTime(2026, 9, 15), [(85, 5)]);
    final moreReps = await logSquats(DateTime(2026, 9, 22), [(85, 6)]);

    final result = await history.watchHistory(squat).first;

    expect(result.recordSessionIds, {heavier, moreReps});
    expect(result.bestWorkout!.session.id, moreReps);
  });

  test('leaves out unfinished workouts and sets without values', () async {
    await logSquats(DateTime(2026, 9, 2), [(80, 5)]);
    final active = await sessions.startSession();
    await sessions.addSet(active, squat);

    final result = await history.watchHistory(squat).first;

    expect(result.workouts, hasLength(1));
    expect(result.workouts.single.sets, hasLength(1));
  });

  test('estimates a one rep max with Epley', () {
    ExerciseSet set(double weight, int reps) => ExerciseSet(
      id: 0,
      sessionId: 0,
      exerciseId: 0,
      position: 0,
      weightKg: weight,
      reps: reps,
    );

    expect(estimatedOneRepMaxKg(set(100, 1)), 100);
    expect(estimatedOneRepMaxKg(set(90, 10)), 120);
    expect(
      ProgressMetric.estimatedOneRepMax.bestIn([set(100, 1), set(90, 10)]),
      120,
    );
  });
}
