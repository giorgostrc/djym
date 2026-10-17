import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loggym/data/database/app_database.dart';

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
}
