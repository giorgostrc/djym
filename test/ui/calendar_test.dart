import 'package:djym/app.dart';
import 'package:djym/data/database/app_database.dart';
import 'package:djym/data/database/database_provider.dart';
import 'package:djym/data/repositories/exercise_repository.dart';
import 'package:djym/data/repositories/workout_session_repository.dart';
import 'package:djym/data/services/wger_client.dart';
import 'package:djym/domain/tracking_type.dart';
import 'package:djym/ui/core/clock_provider.dart';
import 'package:djym/ui/core/keep_screen_on.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late AppDatabase database;
  late WorkoutSessionRepository sessions;
  late int squatId;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    sessions = WorkoutSessionRepository(database);
    squatId = await ExerciseRepository(database).saveExercise(
      title: 'Squat',
      trackingType: TrackingType.weightReps,
      muscleIds: const [],
    );
  });

  tearDown(() => database.close());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          clockProvider.overrideWith((ref) => Stream.value(DateTime.now())),
          keepScreenOnProvider.overrideWithValue(({required on}) async {}),
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

  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Future<void> logFinishedSquat() async {
    final id = await sessions.startSession();
    await sessions.addExercises(id, [squatId]);
    final set = await database.select(database.exerciseSets).getSingle();
    await sessions.updateSet(
      set.id,
      const ExerciseSetsCompanion(
        reps: Value(5),
        weightKg: Value(100),
        comment: Value('Belt on'),
      ),
    );
    await sessions.finishSession(id);
  }

  testWidgets('opens on today with a way to start a workout', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('No workouts'), findsOneWidget);
    expect(find.text('Start workout'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets("lists today's workout and opens its details", (tester) async {
    await logFinishedSquat();
    await pumpApp(tester);

    expect(find.text('Squat'), findsOneWidget);
    expect(find.textContaining('1 set'), findsOneWidget);

    await tester.tap(find.text('Squat'));
    await tester.pumpAndSettle();

    expect(find.text('100 kg × 5'), findsOneWidget);
    expect(find.text('Belt on'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('deleting from the details removes the workout', (tester) async {
    await logFinishedSquat();
    await pumpApp(tester);
    await tester.tap(find.text('Squat'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete workout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('No workouts'), findsOneWidget);
    expect(await database.select(database.workoutSessions).get(), isEmpty);
    expect(await database.select(database.exerciseSets).get(), isEmpty);

    await unmountApp(tester);
  });

  testWidgets(
    'logs a past workout on an earlier day',
    (tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('1').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log workout'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Squat'));
      await tester.pump();
      await tester.tap(find.text('Add 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Squat'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'reps'), '8');
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      final session = await database
          .select(database.workoutSessions)
          .getSingle();
      final now = DateTime.now();
      expect(session.startedAt, DateTime(now.year, now.month, 1, 18));
      expect(find.text('Squat'), findsOneWidget);

      await unmountApp(tester);
    },
    skip: DateTime.now().day == 1,
  );

  testWidgets(
    'leaving a past workout with nothing logged removes it',
    (tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('1').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log workout'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(await database.select(database.workoutSessions).get(), isEmpty);
      expect(find.text('No workouts'), findsOneWidget);

      await unmountApp(tester);
    },
    skip: DateTime.now().day == 1,
  );

  testWidgets('a future day offers no workout button', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.chevron_right).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('15').first);
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);

    await unmountApp(tester);
  });

  testWidgets(
    'a past day offers logging even while a workout runs',
    (tester) async {
      await sessions.startSession();
      await pumpApp(tester);

      expect(find.byType(FloatingActionButton), findsNothing);

      await tester.tap(find.text('1').first);
      await tester.pumpAndSettle();

      expect(find.text('Log workout'), findsOneWidget);

      await unmountApp(tester);
    },
    skip: DateTime.now().day == 1,
  );

  testWidgets('the year view sums the year and opens a tapped month', (
    tester,
  ) async {
    final year = DateTime.now().year;
    await sessions.logPastSession(DateTime(year, 1, 5));
    await sessions.logPastSession(DateTime(year, 1, 6));
    await pumpApp(tester);

    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();

    expect(find.text('$year'), findsOneWidget);
    expect(find.text('workouts'), findsOneWidget);
    expect(find.text('2 h'), findsOneWidget);
    expect(find.text('Start workout'), findsNothing);

    await tester.tap(find.byTooltip('Previous year'));
    await tester.pumpAndSettle();

    expect(find.text('No workouts in ${year - 1}'), findsOneWidget);

    await tester.tap(find.byTooltip('Next year'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jan'));
    await tester.pumpAndSettle();

    expect(find.text('January $year'), findsOneWidget);

    await unmountApp(tester);
  });
}
