import 'package:drift/drift.dart';
import 'package:loggym/data/database/tables.dart';
import 'package:loggym/domain/theme_preference.dart';
import 'package:loggym/domain/unit_system.dart';

part 'app_database.g.dart';

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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await into(settingsTable).insert(const SettingsTableCompanion());
    },
    beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
  );
}
