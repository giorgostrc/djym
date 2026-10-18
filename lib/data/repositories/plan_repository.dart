import 'package:djym/data/database/app_database.dart';
import 'package:djym/data/database/database_provider.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlanItem {
  const PlanItem(this.exercise, this.targetSets);

  final Exercise exercise;
  final int targetSets;
}

class PlanOverview {
  const PlanOverview(this.plan, this.items, this.lastUsedAt);

  final WorkoutPlan plan;
  final List<PlanItem> items;
  final DateTime? lastUsedAt;

  int get totalSets => items.fold(0, (total, item) => total + item.targetSets);
}

class PlanRepository {
  const PlanRepository(this._database);

  final AppDatabase _database;

  /// Most recently used plans first, never-used ones after them by name.
  /// Reloads whenever plans, exercises or sessions change, since starting a
  /// workout changes the order.
  Stream<List<PlanOverview>> watchPlans() async* {
    yield await loadPlans();
    await for (final _ in _database.tableUpdates(
      TableUpdateQuery.onAllTables([
        _database.workoutPlans,
        _database.planExercises,
        _database.exercises,
        _database.workoutSessions,
      ]),
    )) {
      yield await loadPlans();
    }
  }

  /// One-off read, for actions that need the plans right now.
  Future<List<PlanOverview>> loadPlans() async {
    final plans = _database.workoutPlans;
    final planExercises = _database.planExercises;
    final exercises = _database.exercises;
    final sessions = _database.workoutSessions;
    final lastUsed = sessions.startedAt.max();

    final lastUsedRows =
        await (_database.selectOnly(sessions)
              ..addColumns([sessions.planId, lastUsed])
              ..where(sessions.planId.isNotNull())
              ..groupBy([sessions.planId]))
            .get();
    final lastUsedByPlan = {
      for (final row in lastUsedRows)
        row.read(sessions.planId)!: row.read(lastUsed),
    };

    final rows =
        await (_database.select(plans).join([
              leftOuterJoin(
                planExercises,
                planExercises.planId.equalsExp(plans.id),
              ),
              leftOuterJoin(
                exercises,
                exercises.id.equalsExp(planExercises.exerciseId),
              ),
            ])..orderBy([
              OrderingTerm.asc(plans.id),
              OrderingTerm.asc(planExercises.position),
            ]))
            .get();

    final overviews = <int, PlanOverview>{};
    for (final row in rows) {
      final plan = row.readTable(plans);
      final overview = overviews.putIfAbsent(
        plan.id,
        () => PlanOverview(plan, [], lastUsedByPlan[plan.id]),
      );
      final exercise = row.readTableOrNull(exercises);
      if (exercise == null) continue;
      overview.items.add(
        PlanItem(exercise, row.readTable(planExercises).targetSets),
      );
    }
    return overviews.values.toList()..sort(_byLastUsedThenName);
  }

  Future<int> savePlan({
    required String name,
    required List<({int exerciseId, int targetSets})> items,
    int? id,
  }) => _database.transaction(() async {
    final row = WorkoutPlansCompanion(
      id: Value.absentIfNull(id),
      name: Value(name),
    );
    final saved = await _database
        .into(_database.workoutPlans)
        .insertReturning(row, onConflict: DoUpdate((_) => row));
    await (_database.delete(
      _database.planExercises,
    )..where((item) => item.planId.equals(saved.id))).go();
    await _database.batch(
      (batch) => batch.insertAll(_database.planExercises, [
        for (final (position, item) in items.indexed)
          PlanExercisesCompanion.insert(
            planId: saved.id,
            exerciseId: item.exerciseId,
            position: position,
            targetSets: item.targetSets,
          ),
      ]),
    );
    return saved.id;
  });

  Future<int> duplicatePlan(PlanOverview overview) => savePlan(
    name: '${overview.plan.name} (copy)',
    items: [
      for (final item in overview.items)
        (exerciseId: item.exercise.id, targetSets: item.targetSets),
    ],
  );

  /// Workouts started from the plan keep their sets; only the link goes.
  Future<void> deletePlan(int id) => (_database.delete(
    _database.workoutPlans,
  )..where((plan) => plan.id.equals(id))).go();
}

int _byLastUsedThenName(PlanOverview a, PlanOverview b) {
  final aUsed = a.lastUsedAt;
  final bUsed = b.lastUsedAt;
  if (aUsed != null && bUsed != null) return bUsed.compareTo(aUsed);
  if (aUsed != null) return -1;
  if (bUsed != null) return 1;
  return a.plan.name.toLowerCase().compareTo(b.plan.name.toLowerCase());
}

final planRepositoryProvider = Provider<PlanRepository>(
  (ref) => PlanRepository(ref.watch(appDatabaseProvider)),
);

final plansProvider = StreamProvider<List<PlanOverview>>(
  (ref) => ref.watch(planRepositoryProvider).watchPlans(),
);
