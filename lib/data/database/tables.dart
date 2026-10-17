// Drift column check constraints reference their own getter by design.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';
import 'package:loggym/domain/theme_preference.dart';
import 'package:loggym/domain/unit_system.dart';

class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 120)();
  TextColumn get formGuidance => text().nullable()();
  TextColumn get thumbnailPath => text().nullable()();
  TextColumn get externalId => text().nullable().unique()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
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
  TextColumn get comment => text().nullable()();
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

  @override
  Set<Column> get primaryKey => {id};
}
