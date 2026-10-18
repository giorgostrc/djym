// Drift column check constraints reference their own getter by design.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';
import 'package:loggym/domain/theme_preference.dart';
import 'package:loggym/domain/tracking_type.dart';
import 'package:loggym/domain/unit_system.dart';

class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 120)();
  TextColumn get formGuidance => text().nullable()();
  TextColumn get externalId => text().nullable().unique()();
  TextColumn get trackingType => textEnum<TrackingType>().withDefault(
    Constant(TrackingType.weightReps.name),
  )();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Kept apart from [Exercises] so lists of exercises never load images.
class ExerciseThumbnails extends Table {
  IntColumn get exerciseId =>
      integer().references(Exercises, #id, onDelete: KeyAction.cascade)();
  BlobColumn get image => blob()();

  @override
  Set<Column> get primaryKey => {exerciseId};
}

class Muscles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
}

class ExerciseMuscles extends Table {
  IntColumn get exerciseId =>
      integer().references(Exercises, #id, onDelete: KeyAction.cascade)();
  IntColumn get muscleId => integer().references(Muscles, #id)();
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {exerciseId, position};

  @override
  List<Set<Column>> get uniqueKeys => [
    {exerciseId, muscleId},
  ];
}

class WorkoutPlans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class PlanExercises extends Table {
  IntColumn get planId =>
      integer().references(WorkoutPlans, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get position => integer()();
  IntColumn get targetSets =>
      integer().check(targetSets.isBiggerThanValue(0))();

  @override
  Set<Column> get primaryKey => {planId, position};
}

class GymSubscriptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 120)();
  IntColumn get costCents =>
      integer().check(costCents.isBiggerOrEqualValue(0))();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
}

class WorkoutSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get planId => integer().nullable().references(
    WorkoutPlans,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// The subscription this workout counts towards, if any.
  IntColumn get subscriptionId => integer().nullable().references(
    GymSubscriptions,
    #id,
    onDelete: KeyAction.setNull,
  )();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
}

class ExerciseSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().references(WorkoutSessions, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get position => integer()();
  IntColumn get reps => integer().nullable()();
  RealColumn get weightKg => real().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  RealColumn get distanceMeters => real().nullable()();
  TextColumn get comment => text().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
}

@DataClassName('Settings')
class SettingsTable extends Table {
  @override
  String get tableName => 'settings';

  IntColumn get id =>
      integer().withDefault(const Constant(1)).check(id.equals(1))();
  TextColumn get firstName => text().nullable()();
  TextColumn get lastName => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get themePreference => textEnum<ThemePreference>().withDefault(
    Constant(ThemePreference.system.name),
  )();
  TextColumn get unitSystem => textEnum<UnitSystem>().withDefault(
    Constant(UnitSystem.metric.name),
  )();
  TextColumn get currencyCode =>
      text().withLength(min: 3, max: 3).withDefault(const Constant('EUR'))();
  DateTimeColumn get lastBackupAt => dateTime().nullable()();
  IntColumn get restSeconds => integer().withDefault(const Constant(180))();
  BoolColumn get restAlertsPrompted =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
