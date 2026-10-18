import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loggym/app.dart';
import 'package:loggym/data/database/app_database.dart';
import 'package:loggym/data/database/database_provider.dart';
import 'package:loggym/data/repositories/exercise_repository.dart';
import 'package:loggym/data/repositories/workout_session_repository.dart';
import 'package:loggym/domain/tracking_type.dart';

void main() {
  late AppDatabase database;
  late int squat;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    squat = await ExerciseRepository(database).saveExercise(
      title: 'Squat',
      trackingType: TrackingType.weightReps,
      muscleIds: const [],
    );
  });

  tearDown(() => database.close());

  Future<void> logSquat(DateTime day, double weight) async {
    final sessions = WorkoutSessionRepository(database);
    final id = await sessions.logPastSession(day);
    await sessions.addSet(id, squat);
    await (database.update(
      database.exerciseSets,
    )..where((set) => set.sessionId.equals(id))).write(
      ExerciseSetsCompanion(weightKg: Value(weight), reps: const Value(5)),
    );
  }

  Future<void> openSquat(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const DjymApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exercises'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Squat'));
    await tester.pumpAndSettle();
  }

  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('shows the best set, records and history', (tester) async {
    await logSquat(DateTime(2026, 9, 2), 80);
    await logSquat(DateTime(2026, 9, 8), 100);
    await openSquat(tester);

    expect(find.text('Personal best'), findsOneWidget);
    expect(find.text('100 kg × 5'), findsWidgets);
    expect(find.text('History · 2'), findsOneWidget);
    expect(find.text('PR'), findsOneWidget);

    await tester.tap(find.text('Personal best'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Edit workout'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('an exercise never done explains what will show up', (
    tester,
  ) async {
    await openSquat(tester);

    expect(find.textContaining('after your first workout'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('edit and delete live in the app bar', (tester) async {
    await openSquat(tester);

    await tester.tap(find.byTooltip('Edit exercise'));
    await tester.pumpAndSettle();

    expect(find.text('Edit exercise'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Exercise options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete exercise'));
    await tester.pumpAndSettle();

    expect(find.text('Squat deleted'), findsOneWidget);
    expect(find.text('No exercises yet'), findsOneWidget);

    await unmountApp(tester);
  });
}
