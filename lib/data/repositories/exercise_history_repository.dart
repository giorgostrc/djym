import 'dart:math';

import 'package:djym/data/database/app_database.dart';
import 'package:djym/data/database/database_provider.dart';
import 'package:djym/data/repositories/workout_session_repository.dart';
import 'package:djym/domain/tracking_type.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

enum ProgressMetric {
  heaviestWeight,
  estimatedOneRepMax,
  mostReps,
  longestDuration,
  longestDistance
  ;

  static List<ProgressMetric> forType(TrackingType type) => switch (type) {
    TrackingType.weightReps => [heaviestWeight, estimatedOneRepMax],
    TrackingType.reps => [mostReps],
    TrackingType.duration => [longestDuration],
    TrackingType.distanceDuration => [longestDistance],
  };

  /// In kg, reps, seconds or metres.
  double? valueOf(ExerciseSet set) => switch (this) {
    heaviestWeight => set.weightKg,
    estimatedOneRepMax => estimatedOneRepMaxKg(set),
    mostReps => set.reps?.toDouble(),
    longestDuration => set.durationSeconds?.toDouble(),
    longestDistance => set.distanceMeters,
  };

  double? bestIn(Iterable<ExerciseSet> sets) =>
      sets.map(valueOf).nonNulls.fold<double?>(null, (best, value) {
        return best == null ? value : max(best, value);
      });
}

/// Epley's formula; a single rep is its own max.
double? estimatedOneRepMaxKg(ExerciseSet set) {
  final weight = set.weightKg;
  final reps = set.reps;
  if (weight == null || reps == null || reps < 1) return null;
  return reps == 1 ? weight : weight * (1 + reps / 30);
}

class ExerciseWorkout {
  const ExerciseWorkout(this.session, this.sets, this.best);

  final WorkoutSession session;
  final List<ExerciseSet> sets;
  final ExerciseSet best;
}

class ExerciseHistory {
  const ExerciseHistory({
    required this.trackingType,
    required this.workouts,
    required this.recordSessionIds,
  });

  final TrackingType trackingType;

  /// Newest first; every workout has at least one logged set.
  final List<ExerciseWorkout> workouts;

  /// Workouts whose best set beat every earlier one.
  final Set<int> recordSessionIds;

  /// The first workout to reach the best set.
  ExerciseWorkout? get bestWorkout => workouts.isEmpty
      ? null
      : workouts.reversed.reduce(
          (best, workout) =>
              compareBest(trackingType, workout.best, best.best) < 0
              ? workout
              : best,
        );
}

class ExerciseHistoryRepository {
  const ExerciseHistoryRepository(this._database);

  final AppDatabase _database;

  Stream<ExerciseHistory> watchHistory(int exerciseId) {
    final sets = _database.exerciseSets;
    final sessions = _database.workoutSessions;
    final exercises = _database.exercises;
    final query =
        _database.select(sets).join([
            innerJoin(sessions, sessions.id.equalsExp(sets.sessionId)),
            innerJoin(exercises, exercises.id.equalsExp(sets.exerciseId)),
          ])
          ..where(
            sets.exerciseId.equals(exerciseId) &
                sessions.finishedAt.isNotNull(),
          )
          ..orderBy([
            OrderingTerm.asc(sessions.startedAt),
            OrderingTerm.asc(sets.position),
          ]);

    return query.watch().map((rows) {
      if (rows.isEmpty) {
        return const ExerciseHistory(
          trackingType: TrackingType.weightReps,
          workouts: [],
          recordSessionIds: {},
        );
      }
      final type = rows.first.readTable(exercises).trackingType;
      final sessionsById = <int, WorkoutSession>{};
      final setsBySession = <int, List<ExerciseSet>>{};
      for (final row in rows) {
        final session = row.readTable(sessions);
        sessionsById[session.id] = session;
        final set = row.readTable(sets);
        if (set.hasValues) {
          setsBySession.putIfAbsent(session.id, () => []).add(set);
        }
      }

      final workouts = [
        for (final MapEntry(key: id, value: logged) in setsBySession.entries)
          ExerciseWorkout(sessionsById[id]!, logged, bestSet(type, logged)!),
      ];
      final recordSessionIds = <int>{};
      ExerciseSet? bestSoFar;
      for (final workout in workouts) {
        final isRecord =
            bestSoFar != null && compareBest(type, workout.best, bestSoFar) < 0;
        if (isRecord) recordSessionIds.add(workout.session.id);
        if (bestSoFar == null || isRecord) bestSoFar = workout.best;
      }

      return ExerciseHistory(
        trackingType: type,
        workouts: workouts.reversed.toList(),
        recordSessionIds: recordSessionIds,
      );
    });
  }
}

final exerciseHistoryRepositoryProvider = Provider<ExerciseHistoryRepository>(
  (ref) => ExerciseHistoryRepository(ref.watch(appDatabaseProvider)),
);

final StreamProviderFamily<ExerciseHistory, int> exerciseHistoryProvider =
    StreamProvider.autoDispose.family<ExerciseHistory, int>(
      (ref, exerciseId) =>
          ref.watch(exerciseHistoryRepositoryProvider).watchHistory(exerciseId),
    );
