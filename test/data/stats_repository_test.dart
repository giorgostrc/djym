import 'package:djym/data/database/app_database.dart';
import 'package:djym/data/repositories/exercise_repository.dart';
import 'package:djym/data/repositories/stats_repository.dart';
import 'package:djym/data/repositories/subscription_repository.dart';
import 'package:djym/data/repositories/workout_session_repository.dart';
import 'package:djym/domain/subscription_period.dart';
import 'package:djym/domain/tracking_type.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late WorkoutSessionRepository sessions;
  late StatsRepository stats;
  late int squat;
  late int plank;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    sessions = WorkoutSessionRepository(database);
    stats = StatsRepository(database);
    final exercises = ExerciseRepository(database);
    squat = await exercises.saveExercise(
      title: 'Squat',
      trackingType: TrackingType.weightReps,
      muscleIds: const [],
    );
    plank = await exercises.saveExercise(
      title: 'Plank',
      trackingType: TrackingType.duration,
      muscleIds: const [],
    );
  });

  tearDown(() => database.close());

  Future<void> logWorkout(DateTime day, Map<int, int> setsPerExercise) async {
    final id = await sessions.logPastSession(day);
    for (final MapEntry(key: exercise, value: count)
        in setsPerExercise.entries) {
      for (var i = 0; i < count; i++) {
        await sessions.addSet(id, exercise);
      }
    }
    await (database.update(
      database.exerciseSets,
    )..where((set) => set.sessionId.equals(id))).write(
      const ExerciseSetsCompanion(
        weightKg: Value(100),
        reps: Value(5),
        durationSeconds: Value(60),
      ),
    );
  }

  test('sums a year of workouts and ranks exercises', () async {
    await logWorkout(DateTime(2026, 3, 2), {squat: 2});
    await logWorkout(DateTime(2026, 3, 2), {plank: 1});
    await logWorkout(DateTime(2026, 3, 9), {squat: 1, plank: 1});
    await logWorkout(DateTime(2026, 3, 10), {squat: 1});
    await logWorkout(DateTime(2025, 12, 31), {squat: 3});
    await sessions.startSession();

    final year = await stats.loadYear(2026);

    expect(year.workoutCount, 4);
    expect(year.workoutsPerDay[DateTime(2026, 3, 2)], 2);
    expect(year.timeTrained, const Duration(hours: 4));
    expect(year.setCount, 6);
    expect(year.activeWeeks, 2);
    expect(year.longestStreakWeeks, 2);
    expect(year.topExercises.map((top) => top.exercise.title), [
      'Squat',
      'Plank',
    ]);
    expect(year.topExercises.first.workoutCount, 3);
  });

  test('subscription spend covers subscriptions starting that year', () async {
    final subscriptions = SubscriptionRepository(database);
    await subscriptions.saveSubscription(
      title: 'Gym',
      costCents: 6000,
      period: SubscriptionPeriod.months(DateTime(2026, 3), 1),
    );
    await subscriptions.saveSubscription(
      title: 'Gym',
      costCents: 6000,
      period: SubscriptionPeriod.months(DateTime(2025, 3), 1),
    );
    await logWorkout(DateTime(2026, 3, 2), {squat: 1});
    await logWorkout(DateTime(2026, 3, 9), {squat: 1});

    final year = await stats.loadYear(2026);

    expect(year.subscriptionSpendCents, 6000);
    expect(year.costPerWorkoutCents, 3000);
  });
}
