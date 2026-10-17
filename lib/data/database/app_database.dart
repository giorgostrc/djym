import 'package:drift/drift.dart';
import 'package:loggym/data/database/app_database.steps.dart';
import 'package:loggym/data/database/tables.dart';
import 'package:loggym/domain/theme_preference.dart';
import 'package:loggym/domain/tracking_type.dart';
import 'package:loggym/domain/unit_system.dart';

part 'app_database.g.dart';

const _muscleNames = [
  'Abs',
  'Biceps',
  'Calves',
  'Chest',
  'Forearms',
  'Glutes',
  'Hamstrings',
  'Lats',
  'Lower back',
  'Obliques',
  'Quads',
  'Shoulders',
  'Traps',
  'Triceps',
];

@DriftDatabase(
  tables: [
    Exercises,
    Muscles,
    ExerciseMuscles,
    WorkoutPlans,
    PlanExercises,
    GymSubscriptions,
    WorkoutSessions,
    ExerciseSets,
    SettingsTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await into(settingsTable).insert(const SettingsTableCompanion());
      await _seedMuscles();
    },
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        await m.addColumn(schema.exercises, schema.exercises.trackingType);
        await m.addColumn(schema.exercises, schema.exercises.archivedAt);
        await m.addColumn(
          schema.exerciseSets,
          schema.exerciseSets.distanceMeters,
        );
        await m.addColumn(schema.exerciseSets, schema.exerciseSets.completedAt);
        await _seedMuscles();
      },
    ),
    beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
  );

  Future<void> _seedMuscles() => batch(
    (batch) => batch.insertAll(
      muscles,
      _muscleNames.map((name) => MusclesCompanion.insert(name: name)),
      mode: InsertMode.insertOrIgnore,
    ),
  );
}
