import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loggym/data/database/app_database.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;
import 'generated/schema_v6.dart' as v6;
import 'generated/schema_v7.dart' as v7;

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

  test('v1 to v2 keeps exercises, defaults their tracking type and seeds '
      'muscles', () async {
    const createdAt = '2026-10-01T10:00:00.000';

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insert(
          oldDb.exercises,
          const v1.ExercisesData(id: 1, title: 'Squat', createdAt: createdAt),
        );
      },
      validateItems: (newDb) async {
        expect(await newDb.select(newDb.exercises).get(), const [
          v2.ExercisesData(
            id: 1,
            title: 'Squat',
            trackingType: 'weightReps',
            createdAt: createdAt,
          ),
        ]);
        expect(await newDb.select(newDb.muscles).get(), hasLength(14));
      },
    );
  });

  test('v2 to v3 keeps settings and defaults the currency to EUR', () async {
    await verifier.testWithDataIntegrity(
      oldVersion: 2,
      newVersion: 3,
      createOld: v2.DatabaseAtV2.new,
      createNew: v3.DatabaseAtV3.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insert(
          oldDb.settings,
          const v2.SettingsData(
            id: 1,
            firstName: 'Alex',
            themePreference: 'dark',
            unitSystem: 'imperial',
          ),
        );
      },
      validateItems: (newDb) async {
        expect(await newDb.select(newDb.settings).get(), const [
          v3.SettingsData(
            id: 1,
            firstName: 'Alex',
            themePreference: 'dark',
            unitSystem: 'imperial',
            currencyCode: 'EUR',
          ),
        ]);
      },
    );
  });

  test(
    'v3 to v4 moves photo files into the database and deletes them',
    () async {
      const createdAt = '2026-10-01T10:00:00.000';
      final support = Directory.systemTemp.createTempSync('loggym_support');
      addTearDown(() => support.deleteSync(recursive: true));
      File('${support.path}/thumbnails/squat.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3]);

      await verifier.testWithDataIntegrity(
        oldVersion: 3,
        newVersion: 4,
        createOld: v3.DatabaseAtV3.new,
        createNew: v4.DatabaseAtV4.new,
        openTestedDatabase: (executor) => AppDatabase(
          executor,
          legacyFilesDirectory: () async => support,
        ),
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.exercises, const [
            v3.ExercisesData(
              id: 1,
              title: 'Squat',
              thumbnailPath: 'thumbnails/squat.png',
              trackingType: 'weightReps',
              createdAt: createdAt,
            ),
            v3.ExercisesData(
              id: 2,
              title: 'Plank',
              thumbnailPath: 'thumbnails/missing.png',
              trackingType: 'duration',
              createdAt: createdAt,
            ),
          ]);
        },
        validateItems: (newDb) async {
          final thumbnails = await newDb.select(newDb.exerciseThumbnails).get();
          expect(thumbnails.single.exerciseId, 1);
          expect(thumbnails.single.image, [1, 2, 3]);
          expect(await newDb.select(newDb.exercises).get(), hasLength(2));
        },
      );

      expect(Directory('${support.path}/thumbnails').existsSync(), isFalse);
    },
  );

  test(
    'v6 to v7 links each workout to the only subscription covering it',
    () async {
      v6.WorkoutSessionsData session(
        int id,
        String day, {
        bool finished = true,
      }) => v6.WorkoutSessionsData(
        id: id,
        startedAt: '${day}T18:00:00.000',
        finishedAt: finished ? '${day}T19:00:00.000' : null,
      );

      await verifier.testWithDataIntegrity(
        oldVersion: 6,
        newVersion: 7,
        createOld: v6.DatabaseAtV6.new,
        createNew: v7.DatabaseAtV7.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch
            ..insertAll(oldDb.gymSubscriptions, const [
              v6.GymSubscriptionsData(
                id: 1,
                title: 'Gym',
                costCents: 6000,
                startDate: '2026-10-01T00:00:00.000',
                endDate: '2026-10-31T00:00:00.000',
              ),
              v6.GymSubscriptionsData(
                id: 2,
                title: 'Yoga',
                costCents: 4000,
                startDate: '2026-10-15T00:00:00.000',
                endDate: '2026-11-14T00:00:00.000',
              ),
            ])
            ..insertAll(oldDb.workoutSessions, [
              session(1, '2026-10-05'),
              session(2, '2026-10-20'),
              session(3, '2026-11-10'),
              session(4, '2026-10-06', finished: false),
              session(5, '2026-12-01'),
            ]);
        },
        validateItems: (newDb) async {
          final sessions = await newDb.select(newDb.workoutSessions).get();
          expect(
            {for (final s in sessions) s.id: s.subscriptionId},
            {
              1: 1,
              2: null,
              3: 2,
              4: null,
              5: null,
            },
          );
        },
      );
    },
  );
}
