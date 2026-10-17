import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loggym/data/database/app_database.dart';
import 'package:loggym/data/database/database_provider.dart';
import 'package:loggym/domain/tracking_type.dart';

class ExerciseWithMuscles {
  const ExerciseWithMuscles(this.exercise, this.muscles);

  final Exercise exercise;
  final List<Muscle> muscles;
}

enum ExerciseRemoval { deleted, archived }

class ExerciseRepository {
  const ExerciseRepository(this._database);

  final AppDatabase _database;

  Stream<List<Muscle>> watchMuscles() => (_database.select(
    _database.muscles,
  )..orderBy([(muscle) => OrderingTerm.asc(muscle.name)])).watch();

  Stream<List<ExerciseWithMuscles>> watchExercises() {
    final exercises = _database.exercises;
    final links = _database.exerciseMuscles;
    final muscles = _database.muscles;

    final query =
        _database.select(exercises).join([
            leftOuterJoin(links, links.exerciseId.equalsExp(exercises.id)),
            leftOuterJoin(muscles, muscles.id.equalsExp(links.muscleId)),
          ])
          ..where(exercises.archivedAt.isNull())
          ..orderBy([
            OrderingTerm.asc(exercises.title.lower()),
            OrderingTerm.asc(exercises.id),
            OrderingTerm.asc(links.position),
          ]);

    return query.watch().map((rows) {
      final grouped = <int, ExerciseWithMuscles>{};
      for (final row in rows) {
        final exercise = row.readTable(exercises);
        final entry = grouped.putIfAbsent(
          exercise.id,
          () => ExerciseWithMuscles(exercise, []),
        );
        final muscle = row.readTableOrNull(muscles);
        if (muscle != null) entry.muscles.add(muscle);
      }
      return grouped.values.toList();
    });
  }

  /// Saving with the wger id of an archived exercise brings that exercise
  /// back instead of creating a duplicate. A null [thumbnailPath] removes the
  /// thumbnail.
  Future<int> saveExercise({
    required String title,
    required TrackingType trackingType,
    required List<int> muscleIds,
    String? formGuidance,
    String? externalId,
    String? thumbnailPath,
    int? id,
  }) => _database.transaction(() async {
    final row = ExercisesCompanion(
      id: Value.absentIfNull(id),
      title: Value(title),
      trackingType: Value(trackingType),
      formGuidance: Value(formGuidance),
      externalId: Value.absentIfNull(externalId),
      thumbnailPath: Value(thumbnailPath),
      archivedAt: const Value(null),
    );
    final saved = await _database
        .into(_database.exercises)
        .insertReturning(
          row,
          onConflict: UpsertMultiple([
            DoUpdate((_) => row),
            DoUpdate((_) => row, target: [_database.exercises.externalId]),
          ]),
        );
    await _replaceMuscles(saved.id, muscleIds);
    return saved.id;
  });

  Future<ExerciseRemoval> removeExercise(int id) =>
      _database.transaction(() async {
        if (await _isUsed(id)) {
          await (_database.update(_database.exercises)
                ..where((exercise) => exercise.id.equals(id)))
              .write(ExercisesCompanion(archivedAt: Value(DateTime.now())));
          return ExerciseRemoval.archived;
        }
        await (_database.delete(
          _database.exercises,
        )..where((exercise) => exercise.id.equals(id))).go();
        return ExerciseRemoval.deleted;
      });

  Future<void> restoreExercise(ExerciseWithMuscles removed) =>
      _database.transaction(() async {
        await _database
            .into(_database.exercises)
            .insertOnConflictUpdate(
              removed.exercise
                  .toCompanion(false)
                  .copyWith(archivedAt: const Value(null)),
            );
        await _replaceMuscles(
          removed.exercise.id,
          removed.muscles.map((muscle) => muscle.id).toList(),
        );
      });

  Future<void> _replaceMuscles(int exerciseId, List<int> muscleIds) async {
    await (_database.delete(
      _database.exerciseMuscles,
    )..where((link) => link.exerciseId.equals(exerciseId))).go();
    await _database.batch(
      (batch) => batch.insertAll(_database.exerciseMuscles, [
        for (final (position, muscleId) in muscleIds.indexed)
          ExerciseMusclesCompanion.insert(
            exerciseId: exerciseId,
            muscleId: muscleId,
            position: position,
          ),
      ]),
    );
  }

  Future<bool> _isUsed(int id) async {
    final used =
        existsQuery(
          _database.select(_database.exerciseSets)
            ..where((set) => set.exerciseId.equals(id)),
        ) |
        existsQuery(
          _database.select(_database.planExercises)
            ..where((planExercise) => planExercise.exerciseId.equals(id)),
        );
    final row = await _database.selectExpressions([used]).getSingle();
    return row.read(used)!;
  }
}

final exerciseRepositoryProvider = Provider<ExerciseRepository>(
  (ref) => ExerciseRepository(ref.watch(appDatabaseProvider)),
);

final exercisesProvider = StreamProvider<List<ExerciseWithMuscles>>(
  (ref) => ref.watch(exerciseRepositoryProvider).watchExercises(),
);

final musclesProvider = StreamProvider<List<Muscle>>(
  (ref) => ref.watch(exerciseRepositoryProvider).watchMuscles(),
);
