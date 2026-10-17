import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:loggym/data/database/app_database.dart';
import 'package:loggym/data/database/database_provider.dart';
import 'package:loggym/domain/tracking_type.dart';

class SessionExercise {
  const SessionExercise(this.exercise, this.sets);

  final Exercise exercise;
  final List<ExerciseSet> sets;
}

class LastPerformance {
  const LastPerformance({required this.date, required this.sets});

  final DateTime date;
  final List<ExerciseSet> sets;
}

class ExerciseRecords {
  const ExerciseRecords({this.allTimeBest, this.lastPerformance});

  final ExerciseSet? allTimeBest;
  final LastPerformance? lastPerformance;
}

class SessionSummary {
  const SessionSummary({
    required this.duration,
    required this.exerciseCount,
    required this.setCount,
    required this.volumeKg,
  });

  final Duration duration;
  final int exerciseCount;
  final int setCount;
  final double volumeKg;
}

extension ExerciseSetValues on ExerciseSet {
  bool get hasValues =>
      reps != null ||
      weightKg != null ||
      durationSeconds != null ||
      distanceMeters != null;
}

/// Orders sets so the best one for [type] comes first.
int _compareBest(TrackingType type, ExerciseSet a, ExerciseSet b) {
  int descending(num? x, num? y) => (y ?? 0).compareTo(x ?? 0);
  return switch (type) {
    TrackingType.weightReps =>
      descending(a.weightKg, b.weightKg) != 0
          ? descending(a.weightKg, b.weightKg)
          : descending(a.reps, b.reps),
    TrackingType.reps => descending(a.reps, b.reps),
    TrackingType.duration => descending(a.durationSeconds, b.durationSeconds),
    TrackingType.distanceDuration => descending(
      a.distanceMeters,
      b.distanceMeters,
    ),
  };
}

ExerciseSet? _best(TrackingType type, Iterable<ExerciseSet> sets) {
  final logged = sets.where((set) => set.hasValues).toList();
  if (logged.isEmpty) return null;
  return (logged..sort((a, b) => _compareBest(type, a, b))).first;
}

class WorkoutSessionRepository {
  const WorkoutSessionRepository(this._database);

  final AppDatabase _database;

  $ExerciseSetsTable get _sets => _database.exerciseSets;
  $WorkoutSessionsTable get _sessions => _database.workoutSessions;

  Stream<List<WorkoutSession>> watchSessionsInMonth(DateTime month) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final query = _database.select(_sessions)
      ..where(
        (session) =>
            session.startedAt.isBiggerOrEqualValue(start) &
            session.startedAt.isSmallerThanValue(end) &
            session.finishedAt.isNotNull(),
      )
      ..orderBy([(session) => OrderingTerm.asc(session.startedAt)]);
    return query.watch();
  }

  SimpleSelectStatement<$WorkoutSessionsTable, WorkoutSession>
  _activeSessionQuery() => _database.select(_sessions)
    ..where((session) => session.finishedAt.isNull())
    ..limit(1);

  Stream<WorkoutSession?> watchActiveSession() =>
      _activeSessionQuery().watchSingleOrNull();

  Stream<WorkoutSession?> watchSession(int sessionId) => (_database.select(
    _sessions,
  )..where((session) => session.id.equals(sessionId))).watchSingleOrNull();

  /// Only one session can be active; starting again returns that one.
  Future<int> startSession() => _database.transaction(() async {
    final active = await _activeSessionQuery().getSingleOrNull();
    if (active != null) return active.id;
    return _database
        .into(_sessions)
        .insert(WorkoutSessionsCompanion.insert(startedAt: DateTime.now()));
  });

  Stream<List<SessionExercise>> watchSessionExercises(int sessionId) =>
      _sessionExercisesQuery(sessionId).watch().map(_groupByExercise);

  JoinedSelectStatement<HasResultSet, dynamic> _sessionExercisesQuery(
    int sessionId,
  ) {
    final exercises = _database.exercises;
    return _database.select(_sets).join([
        innerJoin(exercises, exercises.id.equalsExp(_sets.exerciseId)),
      ])
      ..where(_sets.sessionId.equals(sessionId))
      ..orderBy([OrderingTerm.asc(_sets.position)]);
  }

  List<SessionExercise> _groupByExercise(List<TypedResult> rows) {
    final grouped = <int, SessionExercise>{};
    for (final row in rows) {
      final exercise = row.readTable(_database.exercises);
      grouped
          .putIfAbsent(exercise.id, () => SessionExercise(exercise, []))
          .sets
          .add(row.readTable(_sets));
    }
    return grouped.values.toList();
  }

  /// Each exercise starts with one empty set ready to fill in.
  Future<void> addExercises(int sessionId, List<int> exerciseIds) =>
      _database.transaction(() async {
        for (final exerciseId in exerciseIds) {
          await addSet(sessionId, exerciseId);
        }
      });

  Future<void> addSet(int sessionId, int exerciseId) async {
    final position = await _nextPosition(sessionId);
    await _database
        .into(_sets)
        .insert(
          ExerciseSetsCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            position: position,
          ),
        );
  }

  Future<void> updateSet(int setId, ExerciseSetsCompanion changes) =>
      (_database.update(_sets)..where((set) => set.id.equals(setId))).write(
        changes,
      );

  Future<void> deleteSets(List<ExerciseSet> sets) => (_database.delete(
    _sets,
  )..where((set) => set.id.isIn(sets.map((set) => set.id)))).go();

  Future<void> restoreSets(List<ExerciseSet> sets) => _database.batch(
    (batch) => batch.insertAllOnConflictUpdate(_sets, sets),
  );

  /// Rewrites positions so exercises follow [exercisesInOrder] while each
  /// keeps its own set order.
  Future<void> reorderExercises(
    List<SessionExercise> exercisesInOrder,
  ) => _database.batch((batch) {
    var position = 0;
    for (final entry in exercisesInOrder) {
      for (final set in entry.sets) {
        batch.update(
          _sets,
          ExerciseSetsCompanion(position: Value(position++)),
          where: (row) => row.id.equals(set.id),
        );
      }
    }
  });

  Future<void> updateNotes(int sessionId, String notes) =>
      (_database.update(_sessions)..where((s) => s.id.equals(sessionId))).write(
        WorkoutSessionsCompanion(notes: Value(notes)),
      );

  Future<ExerciseRecords> exerciseRecords({
    required Exercise exercise,
    required int excludingSessionId,
  }) async {
    final query =
        _database.select(_sets).join([
            innerJoin(_sessions, _sessions.id.equalsExp(_sets.sessionId)),
          ])
          ..where(
            _sets.exerciseId.equals(exercise.id) &
                _sessions.finishedAt.isNotNull() &
                _sessions.id.equals(excludingSessionId).not(),
          )
          ..orderBy([
            OrderingTerm.desc(_sessions.startedAt),
            OrderingTerm.asc(_sets.position),
          ]);
    final rows = await query.get();
    if (rows.isEmpty) return const ExerciseRecords();

    final lastSession = rows.first.readTable(_sessions);
    final sets = [for (final row in rows) row.readTable(_sets)];
    return ExerciseRecords(
      allTimeBest: _best(exercise.trackingType, sets),
      lastPerformance: LastPerformance(
        date: lastSession.startedAt,
        sets: [
          for (final set in sets)
            if (set.sessionId == lastSession.id) set,
        ],
      ),
    );
  }

  /// Drops sets without values and closes the session.
  Future<SessionSummary> finishSession(int sessionId) =>
      _database.transaction(() async {
        final exercises = _groupByExercise(
          await _sessionExercisesQuery(sessionId).get(),
        );
        final logged = [
          for (final entry in exercises)
            for (final set in entry.sets)
              if (set.hasValues) set,
        ];
        await deleteSets([
          for (final entry in exercises)
            for (final set in entry.sets)
              if (!set.hasValues) set,
        ]);

        final finishedAt = DateTime.now();
        final session =
            await (_database.update(
              _sessions,
            )..where((s) => s.id.equals(sessionId))).writeReturning(
              WorkoutSessionsCompanion(finishedAt: Value(finishedAt)),
            );

        return SessionSummary(
          duration: finishedAt.difference(session.single.startedAt),
          exerciseCount: {for (final set in logged) set.exerciseId}.length,
          setCount: logged.length,
          volumeKg: logged.fold(
            0,
            (total, set) => total + (set.weightKg ?? 0) * (set.reps ?? 0),
          ),
        );
      });

  Future<void> discardSession(int sessionId) =>
      (_database.delete(_sessions)..where((s) => s.id.equals(sessionId))).go();

  Future<int> _nextPosition(int sessionId) async {
    final maxPosition = _sets.position.max();
    final row =
        await (_database.selectOnly(_sets)
              ..addColumns([maxPosition])
              ..where(_sets.sessionId.equals(sessionId)))
            .getSingle();
    return (row.read(maxPosition) ?? -1) + 1;
  }
}

final workoutSessionRepositoryProvider = Provider<WorkoutSessionRepository>(
  (ref) => WorkoutSessionRepository(ref.watch(appDatabaseProvider)),
);

final StreamProviderFamily<List<WorkoutSession>, DateTime>
sessionsInMonthProvider = StreamProvider.family<List<WorkoutSession>, DateTime>(
  (ref, month) =>
      ref.watch(workoutSessionRepositoryProvider).watchSessionsInMonth(month),
);

final activeSessionProvider = StreamProvider<WorkoutSession?>(
  (ref) => ref.watch(workoutSessionRepositoryProvider).watchActiveSession(),
);

final StreamProviderFamily<WorkoutSession?, int> sessionProvider =
    StreamProvider.family<WorkoutSession?, int>(
      (ref, sessionId) =>
          ref.watch(workoutSessionRepositoryProvider).watchSession(sessionId),
    );

final StreamProviderFamily<List<SessionExercise>, int>
sessionExercisesProvider = StreamProvider.family<List<SessionExercise>, int>(
  (ref, sessionId) => ref
      .watch(workoutSessionRepositoryProvider)
      .watchSessionExercises(sessionId),
);

final FutureProviderFamily<ExerciseRecords, (Exercise, int)>
exerciseRecordsProvider =
    FutureProvider.family<ExerciseRecords, (Exercise, int)>(
      (ref, key) => ref
          .watch(workoutSessionRepositoryProvider)
          .exerciseRecords(exercise: key.$1, excludingSessionId: key.$2),
    );
