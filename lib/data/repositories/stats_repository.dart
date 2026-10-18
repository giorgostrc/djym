import 'package:djym/data/database/app_database.dart';
import 'package:djym/data/database/database_provider.dart';
import 'package:djym/data/repositories/subscription_repository.dart';
import 'package:djym/data/repositories/workout_session_repository.dart';
import 'package:djym/domain/subscription_period.dart';
import 'package:djym/domain/training_weeks.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

class ExerciseFrequency {
  const ExerciseFrequency(this.exercise, this.workoutCount);

  final Exercise exercise;
  final int workoutCount;
}

class YearStats {
  const YearStats({
    required this.year,
    required this.workoutsPerDay,
    required this.timeTrained,
    required this.setCount,
    required this.volumeKg,
    required this.topExercises,
    required this.subscriptionSpendCents,
    required this.subscriptionWorkouts,
  });

  final int year;

  /// Finished workouts per local calendar day.
  final Map<DateTime, int> workoutsPerDay;
  final Duration timeTrained;
  final int setCount;
  final double volumeKg;

  /// Up to five exercises, done in the most workouts first.
  final List<ExerciseFrequency> topExercises;

  /// What subscriptions starting this year cost, and the workouts that
  /// counted towards them.
  final int subscriptionSpendCents;
  final int subscriptionWorkouts;

  int get workoutCount => workoutsPerDay.values.fold(0, (a, b) => a + b);

  int get activeWeeks =>
      {for (final day in workoutsPerDay.keys) weekStart(day)}.length;

  int get longestStreakWeeks => longestWeekStreak(workoutsPerDay.keys);

  int? get costPerWorkoutCents => subscriptionWorkouts == 0
      ? null
      : (subscriptionSpendCents / subscriptionWorkouts).round();
}

class StatsRepository {
  const StatsRepository(this._database);

  final AppDatabase _database;

  Stream<YearStats> watchYear(int year) async* {
    yield await loadYear(year);
    await for (final _ in _database.tableUpdates(
      TableUpdateQuery.onAllTables([
        _database.workoutSessions,
        _database.exerciseSets,
        _database.exercises,
        _database.gymSubscriptions,
      ]),
    )) {
      yield await loadYear(year);
    }
  }

  Future<YearStats> loadYear(int year) async {
    final sessions = _database.workoutSessions;
    final sets = _database.exerciseSets;
    final exercises = _database.exercises;
    final rows =
        await (_database.select(sessions).join([
              leftOuterJoin(sets, sets.sessionId.equalsExp(sessions.id)),
              leftOuterJoin(exercises, exercises.id.equalsExp(sets.exerciseId)),
            ])..where(
              sessions.startedAt.isBiggerOrEqualValue(DateTime(year)) &
                  sessions.startedAt.isSmallerThanValue(DateTime(year + 1)) &
                  sessions.finishedAt.isNotNull(),
            ))
            .get();

    final workouts = <int, WorkoutSession>{};
    final exercisesById = <int, Exercise>{};
    final workoutsByExercise = <int, Set<int>>{};
    var setCount = 0;
    var volumeKg = 0.0;
    for (final row in rows) {
      final session = row.readTable(sessions);
      workouts[session.id] = session;
      final set = row.readTableOrNull(sets);
      final exercise = row.readTableOrNull(exercises);
      if (set == null || exercise == null || !set.hasValues) continue;

      setCount++;
      volumeKg += (set.weightKg ?? 0) * (set.reps ?? 0);
      exercisesById[exercise.id] = exercise;
      (workoutsByExercise[exercise.id] ??= {}).add(session.id);
    }

    final workoutsPerDay = <DateTime, int>{};
    var timeTrained = Duration.zero;
    for (final session in workouts.values) {
      final day = dateOnly(session.startedAt);
      workoutsPerDay[day] = (workoutsPerDay[day] ?? 0) + 1;
      timeTrained += session.finishedAt!.difference(session.startedAt);
    }

    final topExercises =
        [
          for (final MapEntry(key: id, value: sessionIds)
              in workoutsByExercise.entries)
            ExerciseFrequency(exercisesById[id]!, sessionIds.length),
        ]..sort(
          (a, b) => b.workoutCount != a.workoutCount
              ? b.workoutCount.compareTo(a.workoutCount)
              : a.exercise.title.compareTo(b.exercise.title),
        );

    final subscriptions = [
      for (final overview in await SubscriptionRepository(
        _database,
      ).loadSubscriptions())
        if (overview.period.start.year == year) overview,
    ];

    return YearStats(
      year: year,
      workoutsPerDay: workoutsPerDay,
      timeTrained: timeTrained,
      setCount: setCount,
      volumeKg: volumeKg,
      topExercises: topExercises.take(5).toList(),
      subscriptionSpendCents: subscriptions.fold(
        0,
        (total, overview) => total + overview.subscription.costCents,
      ),
      subscriptionWorkouts: subscriptions.fold(
        0,
        (total, overview) => total + overview.sessionCount,
      ),
    );
  }
}

final statsRepositoryProvider = Provider<StatsRepository>(
  (ref) => StatsRepository(ref.watch(appDatabaseProvider)),
);

final StreamProviderFamily<YearStats, int> yearStatsProvider = StreamProvider
    .autoDispose
    .family<YearStats, int>(
      (ref, year) => ref.watch(statsRepositoryProvider).watchYear(year),
    );
