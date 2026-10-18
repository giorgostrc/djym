import 'dart:io';

import 'package:drift/drift.dart';
import 'package:loggym/data/database/app_database.steps.dart';
import 'package:loggym/data/database/tables.dart';
import 'package:loggym/domain/subscription_period.dart';
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
  AppDatabase(super.e, {this.legacyFilesDirectory});

  /// Before schema v4, photos were files under this directory; the upgrade
  /// moves them into [ExerciseThumbnails].
  final Future<Directory> Function()? legacyFilesDirectory;

  static const currentSchemaVersion = 7;

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
        await m.addColumn(schema.exercises, schema.exercises.trackingType);
        await m.addColumn(schema.exercises, schema.exercises.archivedAt);
        await m.addColumn(
          schema.exerciseSets,
          schema.exerciseSets.distanceMeters,
        );
        await m.addColumn(schema.exerciseSets, schema.exerciseSets.completedAt);
        await _seedMuscles();
      },
      from2To3: (m, schema) async {
        await m.addColumn(schema.settings, schema.settings.currencyCode);
        await m.addColumn(schema.settings, schema.settings.lastBackupAt);
      },
      from3To4: (m, schema) async {
        await m.createTable(schema.exerciseThumbnails);
        await _moveLegacyThumbnailsIntoDatabase();
        await m.alterTable(TableMigration(schema.exercises));
      },
      from4To5: (m, schema) async {
        await m.addColumn(
          schema.workoutSessions,
          schema.workoutSessions.planId,
        );
      },
      from5To6: (m, schema) async {
        await m.addColumn(schema.settings, schema.settings.restSeconds);
        await m.addColumn(schema.settings, schema.settings.restAlertsPrompted);
      },
      from6To7: (m, schema) async {
        await m.addColumn(
          schema.workoutSessions,
          schema.workoutSessions.subscriptionId,
        );
        await _linkSessionsToTheirOnlySubscription();
      },
    ),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      final before = details.versionBefore;
      if (before != null && before < 4) await _deleteLegacyThumbnails();
    },
  );

  Future<void> _moveLegacyThumbnailsIntoDatabase() async {
    final directory = await legacyFilesDirectory?.call();
    if (directory == null) return;

    final rows = await customSelect(
      'SELECT id, thumbnail_path FROM exercises '
      'WHERE thumbnail_path IS NOT NULL',
    ).get();
    for (final row in rows) {
      final file = File(
        '${directory.path}/${row.read<String>('thumbnail_path')}',
      );
      if (!file.existsSync()) continue;
      await customInsert(
        'INSERT INTO exercise_thumbnails (exercise_id, image) VALUES (?, ?)',
        variables: [
          Variable.withInt(row.read<int>('id')),
          Variable.withBlob(await file.readAsBytes()),
        ],
      );
    }
  }

  /// Before schema v7 every workout counted for every subscription; a
  /// workout covered by exactly one subscription now counts for that one.
  Future<void> _linkSessionsToTheirOnlySubscription() async {
    final subscriptions = await customSelect(
      'SELECT id, start_date, end_date FROM gym_subscriptions',
    ).get();
    final sessions = await customSelect(
      'SELECT id, started_at FROM workout_sessions '
      'WHERE finished_at IS NOT NULL',
    ).get();
    for (final session in sessions) {
      final startedAt = session.read<DateTime>('started_at');
      final covering = [
        for (final subscription in subscriptions)
          if (SubscriptionPeriod(
            subscription.read<DateTime>('start_date'),
            subscription.read<DateTime>('end_date'),
          ).contains(startedAt))
            subscription.read<int>('id'),
      ];
      if (covering.length != 1) continue;
      await customUpdate(
        'UPDATE workout_sessions SET subscription_id = ? WHERE id = ?',
        variables: [
          Variable.withInt(covering.single),
          Variable.withInt(session.read<int>('id')),
        ],
      );
    }
  }

  /// Runs only once the upgrade has committed, so a failed migration never
  /// loses the original files.
  Future<void> _deleteLegacyThumbnails() async {
    final directory = await legacyFilesDirectory?.call();
    if (directory == null) return;
    final thumbnails = Directory('${directory.path}/thumbnails');
    if (thumbnails.existsSync()) await thumbnails.delete(recursive: true);
  }

  Future<void> _seedMuscles() => batch(
    (batch) => batch.insertAll(
      muscles,
      _muscleNames.map((name) => MusclesCompanion.insert(name: name)),
      mode: InsertMode.insertOrIgnore,
    ),
  );
}
