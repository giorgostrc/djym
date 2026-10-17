import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loggym/app.dart';
import 'package:loggym/data/database/app_database.dart';
import 'package:loggym/data/database/database_provider.dart';
import 'package:loggym/data/repositories/exercise_repository.dart';
import 'package:loggym/domain/tracking_type.dart';
import 'package:loggym/ui/exercises/exercise_picker.dart';
import 'package:loggym/ui/exercises/exercises_screen.dart';

void main() {
  late AppDatabase database;
  late ExerciseRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = ExerciseRepository(database);
  });

  tearDown(() => database.close());

  Future<void> openExercisesTab(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const LogGymApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exercises'));
    await tester.pumpAndSettle();
  }

  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Future<int> addExercise(String title) => repository.saveExercise(
    title: title,
    trackingType: TrackingType.weightReps,
    muscleIds: const [],
  );

  testWidgets('creates the first exercise from the empty state', (
    tester,
  ) async {
    await openExercisesTab(tester);

    await tester.tap(find.text('Create your first exercise'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Dips');
    await tester.tap(find.text('Triceps'));
    await tester.tap(find.text('Chest'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(ExercisesScreen), findsOneWidget);
    expect(find.text('Dips'), findsOneWidget);
    expect(find.text('Triceps, Chest'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('asks before discarding unsaved changes', (tester) async {
    await openExercisesTab(tester);

    await tester.tap(find.text('Create your first exercise'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Dips');
    await tester.pump();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('No exercises yet'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('swipe deletes an exercise and undo brings it back', (
    tester,
  ) async {
    await addExercise('Dips');
    await openExercisesTab(tester);

    await tester.drag(find.text('Dips'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Dips deleted'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('Dips'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('search narrows the list', (tester) async {
    await addExercise('Dips');
    await addExercise('Squat');
    await openExercisesTab(tester);

    await tester.enterText(find.byType(SearchBar), 'squ');
    await tester.pumpAndSettle();

    expect(find.text('Squat'), findsOneWidget);
    expect(find.text('Dips'), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('picker returns exercises in selection order and creates '
      'missing ones inline', (tester) async {
    final dipsId = await addExercise('Dips');
    final squatId = await addExercise('Squat');
    await openExercisesTab(tester);

    final picked = showExercisePicker(
      tester.element(find.byType(ExercisesScreen)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Squat').last);
    await tester.tap(find.text('Dips').last);
    await tester.enterText(find.byType(TextField).first, 'Plank');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create "Plank"'));
    await tester.pumpAndSettle();

    expect(find.text('New exercise'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add 3'));
    await tester.pumpAndSettle();

    final plank = await (database.select(
      database.exercises,
    )..where((exercise) => exercise.title.equals('Plank'))).getSingle();
    expect(await picked, [squatId, dipsId, plank.id]);

    await unmountApp(tester);
  });
}
