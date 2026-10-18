import 'package:drift/drift.dart';
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

  static const currentSchemaVersion = 1;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await into(settingsTable).insert(const SettingsTableCompanion());
      await _seedMuscles();
    },
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
