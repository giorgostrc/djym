import 'package:djym/data/database/app_database.steps.dart';
import 'package:djym/data/database/tables.dart';
import 'package:djym/domain/theme_preference.dart';
import 'package:djym/domain/tracking_type.dart';
import 'package:djym/domain/unit_system.dart';
import 'package:drift/drift.dart';

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
    ExerciseThumbnails,
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

  static const currentSchemaVersion = 2;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await into(settingsTable).insert(const SettingsTableCompanion());
      await _seedMuscles();
    },
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        // SQLite cannot drop a UNIQUE column, so the table is rebuilt.
        await m.alterTable(TableMigration(schema.exercises));
        // Local midnights such as 2026-10-01T00:00:00.000+03:00 keep only
        // the day they were written on.
        await customStatement(
          'UPDATE gym_subscriptions '
          'SET start_date = substr(start_date, 1, 10), '
          'end_date = substr(end_date, 1, 10)',
        );
      },
    ),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _seedMuscles() => batch(
    (batch) => batch.insertAll(
      muscles,
      _muscleNames.map((name) => MusclesCompanion.insert(name: name)),
    ),
  );
}
