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

class SessionOverview {
  const SessionOverview(this.session, this.exerciseTitles, this.setCount);

  final WorkoutSession session;
  final List<String> exerciseTitles;
  final int setCount;
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

  /// Finished sessions of [month] with the exercises done in each, in the
  /// order they were logged.
  Stream<List<SessionOverview>> watchSessionsInMonth(DateTime month) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final exercises = _database.exercises;
    final query =
        _database.select(_sessions).join([
            leftOuterJoin(_sets, _sets.sessionId.equalsExp(_sessions.id)),
            leftOuterJoin(exercises, exercises.id.equalsExp(_sets.exerciseId)),
          ])
          ..where(
            _sessions.startedAt.isBiggerOrEqualValue(start) &
                _sessions.startedAt.isSmallerThanValue(end) &
                _sessions.finishedAt.isNotNull(),
          )
          ..orderBy([
            OrderingTerm.asc(_sessions.startedAt),
            OrderingTerm.asc(_sets.position),
          ]);

    return query.watch().map((rows) {
      final titles = <int, Set<String>>{};
      final setCounts = <int, int>{};
      final sessions = <int, WorkoutSession>{};
      for (final row in rows) {
        final session = row.readTable(_sessions);
        sessions[session.id] = session;
        final exerciseTitles = titles.putIfAbsent(session.id, () => {});
        final exercise = row.readTableOrNull(exercises);
        if (exercise == null) continue;
        exerciseTitles.add(exercise.title);
        setCounts.update(session.id, (count) => count + 1, ifAbsent: () => 1);
      }
      return [
        for (final MapEntry(key: id, value: session) in sessions.entries)
          SessionOverview(session, titles[id]!.toList(), setCounts[id] ?? 0),
      ];
    });
  }

  /// A workout logged after the fact: it starts at 18:00 on [day], lasts an
  /// hour until edited, and never becomes the active session.
  Future<int> logPastSession(DateTime day, {int? planId}) =>
      _database.transaction(() async {
        final startedAt = DateTime(day.year, day.month, day.day, 18);
        final id = await _database
            .into(_sessions)
            .insert(
              WorkoutSessionsCompanion.insert(
                startedAt: startedAt,
                finishedAt: Value(startedAt.add(const Duration(hours: 1))),
                planId: Value(planId),
              ),
            );
        if (planId != null) await _addPlanSets(id, planId);
        return id;
      });

  Future<void> updateSessionTimes(
    int sessionId, {
    required DateTime startedAt,
    required DateTime finishedAt,
  }) =>
      (_database.update(_sessions)..where((s) => s.id.equals(sessionId))).write(
        WorkoutSessionsCompanion(
          startedAt: Value(startedAt),
          finishedAt: Value(finishedAt),
        ),
      );

  /// Run when leaving a finished session after editing: drops sets without
  /// values, and the session itself when nothing is left.
  Future<void> tidyFinishedSession(int sessionId) =>
      _database.transaction(() async {
        final sets = await (_database.select(
          _sets,
        )..where((set) => set.sessionId.equals(sessionId))).get();
        await deleteSets([
          for (final set in sets)
            if (!set.hasValues) set,
        ]);
        if (sets.every((set) => !set.hasValues)) {
          await deleteSession(sessionId);
        }
      });

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
  /// A [planId] fills the session with the plan's exercises, each with its
  /// target number of empty sets; the plan itself is never changed.
  Future<int> startSession({int? planId}) => _database.transaction(() async {
    final active = await _activeSessionQuery().getSingleOrNull();
    if (active != null) return active.id;
    final id = await _database
        .into(_sessions)
        .insert(
          WorkoutSessionsCompanion.insert(
            startedAt: DateTime.now(),
            planId: Value(planId),
          ),
        );
    if (planId != null) await _addPlanSets(id, planId);
    return id;
  });

  Future<void> _addPlanSets(int sessionId, int planId) async {
    final items =
        await (_database.select(_database.planExercises)
              ..where((item) => item.planId.equals(planId))
              ..orderBy([(item) => OrderingTerm.asc(item.position)]))
            .get();
    for (final item in items) {
      for (var set = 0; set < item.targetSets; set++) {
        await addSet(sessionId, item.exerciseId);
      }
    }
  }

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

  Future<void> deleteSession(int sessionId) =>
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

final StreamProviderFamily<List<SessionOverview>, DateTime>
sessionsInMonthProvider =
    StreamProvider.family<List<SessionOverview>, DateTime>(
      (ref, month) => ref
          .watch(workoutSessionRepositoryProvider)
          .watchSessionsInMonth(month),
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
