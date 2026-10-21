import 'package:djym/app.dart';
import 'package:djym/data/database/app_database.dart';
import 'package:djym/data/database/database_provider.dart';
import 'package:djym/data/repositories/exercise_repository.dart';
import 'package:djym/data/repositories/plan_repository.dart';
import 'package:djym/data/repositories/workout_session_repository.dart';
import 'package:djym/domain/tracking_type.dart';
import 'package:djym/ui/core/clock_provider.dart';
import 'package:djym/ui/core/keep_screen_on.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late int squat;
  late int bench;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    final exercises = ExerciseRepository(database);
    squat = await exercises.saveExercise(
      title: 'Squat',
      trackingType: TrackingType.weightReps,
      muscleIds: const [],
    );
    bench = await exercises.saveExercise(
      title: 'Bench press',
      trackingType: TrackingType.weightReps,
      muscleIds: const [],
    );
  });

  tearDown(() => database.close());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          clockProvider.overrideWith((ref) => Stream.value(DateTime.now())),
          keepScreenOnProvider.overrideWithValue(({required on}) async {}),
        ],
        child: const DjymApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openPlans(WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Plans'));
    await tester.pumpAndSettle();
  }

  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Future<int> savePushDay() => PlanRepository(database).savePlan(
    name: 'Push day',
    items: [
      (exerciseId: bench, targetSets: 3),
      (exerciseId: squat, targetSets: 2),
    ],
  );

  testWidgets('creates a plan with exercises and target sets', (
    tester,
  ) async {
    await openPlans(tester);

    await tester.tap(find.text('Create a plan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Legs');
    await tester.tap(find.text('Add exercises'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Squat'));
    await tester.pump();
    await tester.tap(find.text('Add 1'));
    await tester.pumpAndSettle();

    expect(find.text('3 sets'), findsOneWidget);

    await tester.tap(find.byTooltip('One set more'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Legs'), findsOneWidget);
    expect(find.text('1 exercise · 4 sets'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('starting a plan fills the workout with its sets', (
    tester,
  ) async {
    await savePushDay();
    await openPlans(tester);

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(find.text('Bench press'), findsOneWidget);
    expect(find.text('3 sets'), findsOneWidget);
    expect(find.text('2 sets'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('a plan cannot start while another workout runs', (
    tester,
  ) async {
    await savePushDay();
    await WorkoutSessionRepository(database).startSession();
    await openPlans(tester);

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(find.text('Workout in progress'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(
      await database.select(database.workoutSessions).get(),
      hasLength(1),
    );

    await unmountApp(tester);
  });

  testWidgets('the calendar offers plans when starting a workout', (
    tester,
  ) async {
    await savePushDay();
    await pumpApp(tester);

    await tester.tap(find.text('Start workout'));
    await tester.pumpAndSettle();

    expect(find.text('Empty workout'), findsOneWidget);

    await tester.tap(find.text('Push day'));
    await tester.pumpAndSettle();

    final session = await database.select(database.workoutSessions).getSingle();
    expect(session.planId, isNotNull);
    expect(find.text('Squat'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('deleting a plan from the editor removes it', (tester) async {
    await savePushDay();
    await openPlans(tester);

    await tester.tap(find.text('Push day'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Plan options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('No workout plans yet'), findsOneWidget);

    await unmountApp(tester);
  });
}
