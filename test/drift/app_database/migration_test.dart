// dart format width=80
import 'dart:typed_data';

import 'package:djym/data/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  test(
    'v2 keeps subscription dates as the days they were written on',
    () async {
      await verifier.testWithDataIntegrity(
        oldVersion: 1,
        newVersion: 2,
        createOld: v1.DatabaseAtV1.new,
        createNew: v2.DatabaseAtV2.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) => batch.insert(
          oldDb.gymSubscriptions,
          const v1.GymSubscriptionsData(
            id: 1,
            title: 'City Gym',
            costCents: 6000,
            startDate: '2026-10-01T00:00:00.000+03:00',
            endDate: '2026-10-31T00:00:00.000-05:00',
          ),
        ),
        validateItems: (newDb) async {
          expect(await newDb.select(newDb.gymSubscriptions).get(), const [
            v2.GymSubscriptionsData(
              id: 1,
              title: 'City Gym',
              costCents: 6000,
              startDate: '2026-10-01',
              endDate: '2026-10-31',
            ),
          ]);
        },
      );
    },
  );

  test('v2 drops the wger id and keeps what refers to exercises', () async {
    const createdAt = '2026-10-03T18:00:00.000';
    final image = Uint8List.fromList([1, 2, 3]);

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch
          ..insert(
            oldDb.exercises,
            const v1.ExercisesData(
              id: 1,
              title: 'Bench press',
              externalId: 'wger:bench-uuid',
              trackingType: 'weightReps',
              createdAt: createdAt,
            ),
          )
          ..insert(
            oldDb.exerciseThumbnails,
            v1.ExerciseThumbnailsData(exerciseId: 1, image: image),
          )
          ..insert(oldDb.muscles, const v1.MusclesData(id: 1, name: 'Chest'))
          ..insert(
            oldDb.exerciseMuscles,
            const v1.ExerciseMusclesData(
              exerciseId: 1,
              muscleId: 1,
              position: 0,
            ),
          )
          ..insert(
            oldDb.workoutSessions,
            const v1.WorkoutSessionsData(id: 1, startedAt: createdAt),
          )
          ..insert(
            oldDb.exerciseSets,
            const v1.ExerciseSetsData(
              id: 1,
              sessionId: 1,
              exerciseId: 1,
              position: 0,
              reps: 5,
            ),
          );
      },
      validateItems: (newDb) async {
        expect(await newDb.select(newDb.exercises).get(), const [
          v2.ExercisesData(
            id: 1,
            title: 'Bench press',
            trackingType: 'weightReps',
            createdAt: createdAt,
          ),
        ]);
        expect(await newDb.select(newDb.exerciseThumbnails).get(), [
          v2.ExerciseThumbnailsData(exerciseId: 1, image: image),
        ]);
        expect(await newDb.select(newDb.exerciseMuscles).get(), hasLength(1));
        expect(await newDb.select(newDb.exerciseSets).get(), hasLength(1));
      },
    );
  });
}
