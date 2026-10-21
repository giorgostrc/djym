import 'package:djym/app.dart';
import 'package:djym/data/database/app_database.dart';
import 'package:djym/data/database/database_provider.dart';
import 'package:djym/data/repositories/exercise_repository.dart';
import 'package:djym/data/repositories/settings_repository.dart';
import 'package:djym/data/repositories/workout_session_repository.dart';
import 'package:djym/data/services/rest_alerts.dart';
import 'package:djym/data/services/wger_client.dart';
import 'package:djym/domain/tracking_type.dart';
import 'package:djym/domain/unit_system.dart';
import 'package:djym/ui/core/clock_provider.dart';
import 'package:djym/ui/core/keep_screen_on.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../fakes/fake_rest_alerts.dart';

void main() {
  late AppDatabase database;
  late List<bool> screenAwake;
  late FakeRestAlerts restAlerts;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    screenAwake = [];
    restAlerts = FakeRestAlerts();
    await ExerciseRepository(database).saveExercise(
      title: 'Squat',
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
          keepScreenOnProvider.overrideWithValue(
            ({required on}) async => screenAwake.add(on),
          ),
          restAlertsProvider.overrideWithValue(restAlerts),
          wgerClientProvider.overrideWithValue(
            WgerClient(
              MockClient((_) async => http.Response('{"results": []}', 200)),
            ),
          ),
        ],
        child: const DjymApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> startWorkoutWithSquat(WidgetTester tester) async {
    await tester.tap(find.text('Start workout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Squat'));
    await tester.pump();
    await tester.tap(find.text('Add 1'));
    await tester.pumpAndSettle();
  }

  Future<void> expandSquat(WidgetTester tester) async {
    await tester.tap(find.text('Squat'));
    await tester.pumpAndSettle();
  }

  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  testWidgets('logs a set, finishes and shows the summary', (tester) async {
    await pumpApp(tester);
    await startWorkoutWithSquat(tester);
    await expandSquat(tester);

    expect(screenAwake, [true]);

    await tester.enterText(field('kg'), '100');
    await tester.enterText(field('reps'), '5');
    await tester.tap(find.byTooltip('Mark set done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();

    expect(find.text('Workout complete'), findsOneWidget);
    expect(find.text('500 kg'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();

    final sets = await database.select(database.exerciseSets).get();
    expect(sets.single.weightKg, 100);
    expect(sets.single.reps, 5);
    expect(sets.single.completedAt, isNotNull);
    expect(find.text('Start workout'), findsOneWidget);
    expect(screenAwake, [true, false]);

    await unmountApp(tester);
  });

  testWidgets('a done set starts the rest, which can be adjusted', (
    tester,
  ) async {
    await pumpApp(tester);
    await startWorkoutWithSquat(tester);
    await expandSquat(tester);

    await tester.tap(find.byTooltip('Mark set done'));
    await tester.pumpAndSettle();

    expect(find.text('3:00'), findsOneWidget);
    expect(restAlerts.scheduled, hasLength(1));

    await tester.tap(find.text('+15 s'));
    await tester.pump();

    expect(find.text('3:15'), findsOneWidget);
    expect(restAlerts.scheduled, hasLength(2));

    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(find.text('Skip'), findsNothing);
    expect(restAlerts.cancelled, isTrue);

    await unmountApp(tester);
  });

  testWidgets('the first rest asks once before alerting', (tester) async {
    restAlerts.notificationsEnabled = false;
    await pumpApp(tester);
    await startWorkoutWithSquat(tester);
    await expandSquat(tester);

    await tester.tap(find.byTooltip('Mark set done'));
    await tester.pumpAndSettle();

    expect(find.text('Alert when rest is over?'), findsOneWidget);

    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();

    expect(restAlerts.permissionRequests, 1);
    expect(restAlerts.scheduled, hasLength(2));

    await tester.tap(find.text('Add set'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mark set done').last);
    await tester.pumpAndSettle();

    expect(find.text('Alert when rest is over?'), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('no rest starts when the rest timer is off', (tester) async {
    await SettingsRepository(database).setRestSeconds(0);
    await pumpApp(tester);
    await startWorkoutWithSquat(tester);
    await expandSquat(tester);

    await tester.tap(find.byTooltip('Mark set done'));
    await tester.pumpAndSettle();

    expect(find.text('Skip'), findsNothing);
    expect(restAlerts.scheduled, isEmpty);

    await unmountApp(tester);
  });

  testWidgets('the banner brings back a workout left running', (tester) async {
    await pumpApp(tester);
    await startWorkoutWithSquat(tester);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exercises'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Workout in progress'), findsOneWidget);

    await tester.tap(find.textContaining('Workout in progress'));
    await tester.pumpAndSettle();

    expect(find.text('Squat'), findsOneWidget);
    expect(find.text('1 set'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('finishing with nothing logged offers to discard', (
    tester,
  ) async {
    await pumpApp(tester);
    await startWorkoutWithSquat(tester);

    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();

    expect(find.text('Nothing logged yet'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(await database.select(database.workoutSessions).get(), isEmpty);
    expect(find.text('Start workout'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('weights typed in pounds are stored in kilograms', (
    tester,
  ) async {
    await SettingsRepository(database).setUnitSystem(UnitSystem.imperial);
    await pumpApp(tester);
    await startWorkoutWithSquat(tester);
    await expandSquat(tester);

    await tester.enterText(field('lb'), '220.5');
    await tester.pump();

    final set = await database.select(database.exerciseSets).getSingle();
    expect(set.weightKg, closeTo(100, 0.02));

    await unmountApp(tester);
  });

  testWidgets('shows the best set and every set of last time with comments', (
    tester,
  ) async {
    final sessions = WorkoutSessionRepository(database);
    final squat = await database.select(database.exercises).getSingle();
    final previous = await sessions.startSession();
    await sessions.addExercises(previous, [squat.id]);
    final set = await database.select(database.exerciseSets).getSingle();
    await sessions.updateSet(
      set.id,
      const ExerciseSetsCompanion(
        reps: Value(5),
        weightKg: Value(100),
        comment: Value('Felt heavy'),
      ),
    );
    await sessions.finishSession(previous);

    await pumpApp(tester);
    await startWorkoutWithSquat(tester);
    await expandSquat(tester);

    expect(find.text('Best: 100 kg × 5'), findsOneWidget);
    final lastTime = find.textContaining('Last ·', findRichText: true);
    expect(lastTime, findsOneWidget);
    expect(find.byIcon(Icons.mode_comment_outlined), findsOneWidget);

    await tester.tap(lastTime);
    await tester.pumpAndSettle();

    expect(find.textContaining('Last time ·'), findsOneWidget);
    expect(find.text('100 kg × 5'), findsOneWidget);
    expect(find.text('Felt heavy'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('cards start collapsed and summarise their sets', (
    tester,
  ) async {
    await pumpApp(tester);
    await startWorkoutWithSquat(tester);

    expect(find.text('1 set'), findsOneWidget);
    expect(find.text('Add set'), findsNothing);

    await expandSquat(tester);
    await tester.tap(find.text('Add set'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mark set done').first);
    await tester.pumpAndSettle();
    await expandSquat(tester);

    expect(find.text('1 of 2 sets done'), findsOneWidget);
    expect(find.byTooltip('Mark set done'), findsNothing);

    await expandSquat(tester);
    await tester.tap(find.byTooltip('Mark set done'));
    await tester.pumpAndSettle();
    await expandSquat(tester);

    expect(
      find.textContaining('Completed · 2 sets', findRichText: true),
      findsOneWidget,
    );

    await unmountApp(tester);
  });
}
