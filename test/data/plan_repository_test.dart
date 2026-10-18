import 'package:djym/data/database/app_database.dart';
import 'package:djym/data/repositories/exercise_repository.dart';
import 'package:djym/data/repositories/plan_repository.dart';
import 'package:djym/data/repositories/workout_session_repository.dart';
import 'package:djym/domain/tracking_type.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late PlanRepository plans;
  late WorkoutSessionRepository sessions;
  late int squat;
  late int bench;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    plans = PlanRepository(database);
    sessions = WorkoutSessionRepository(database);
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

  Future<int> savePushDay() => plans.savePlan(
    name: 'Push day',
    items: [
      (exerciseId: bench, targetSets: 3),
      (exerciseId: squat, targetSets: 2),
    ],
  );

  Future<List<String>> planNames() async => [
    for (final overview in await plans.watchPlans().first) overview.plan.name,
  ];

  test('saves a plan with its exercises in order', () async {
    await savePushDay();

    final [push] = await plans.watchPlans().first;

    expect(push.plan.name, 'Push day');
    expect(push.items.map((item) => item.exercise.title), [
      'Bench press',
      'Squat',
    ]);
    expect(push.items.map((item) => item.targetSets), [3, 2]);
    expect(push.totalSets, 5);
  });

  test('editing replaces the name and exercises', () async {
    final id = await savePushDay();

    await plans.savePlan(
      id: id,
      name: 'Legs',
      items: [(exerciseId: squat, targetSets: 5)],
    );

    final [legs] = await plans.watchPlans().first;
    expect(legs.plan.id, id);
    expect(legs.plan.name, 'Legs');
    expect(legs.items.single.targetSets, 5);
  });

  test('lists recently used plans first, then by name', () async {
    await plans.savePlan(name: 'Zebra', items: const []);
    await plans.savePlan(name: 'Arms', items: const []);
    final used = await savePushDay();

    expect(await planNames(), ['Arms', 'Push day', 'Zebra']);

    await sessions.startSession(planId: used);

    expect(await planNames(), ['Push day', 'Arms', 'Zebra']);
  });

  test('duplicating copies the exercises under a new name', () async {
    await savePushDay();
    final [push] = await plans.watchPlans().first;

    await plans.duplicatePlan(push);

    final copy = (await plans.watchPlans().first).firstWhere(
      (overview) => overview.plan.name == 'Push day (copy)',
    );
    expect(copy.items.map((item) => item.targetSets), [3, 2]);
  });

  test('a session from a plan gets its target sets in plan order', () async {
    final id = await savePushDay();

    final sessionId = await sessions.startSession(planId: id);

    final [first, second] = await sessions
        .watchSessionExercises(sessionId)
        .first;
    expect(first.exercise.title, 'Bench press');
    expect(first.sets, hasLength(3));
    expect(second.exercise.title, 'Squat');
    expect(second.sets, hasLength(2));
  });

  test('a past workout can come from a plan too', () async {
    final id = await savePushDay();

    final sessionId = await sessions.logPastSession(
      DateTime(2026, 10, 3),
      planId: id,
    );

    final exercises = await sessions.watchSessionExercises(sessionId).first;
    expect(exercises, hasLength(2));
  });

  test('changing a session never changes its plan', () async {
    final id = await savePushDay();
    final sessionId = await sessions.startSession(planId: id);
    final [benchEntry, _] = await sessions
        .watchSessionExercises(sessionId)
        .first;

    await sessions.deleteSets(benchEntry.sets);

    final [push] = await plans.watchPlans().first;
    expect(push.items, hasLength(2));
  });

  test('deleting a plan keeps the workouts done with it', () async {
    final id = await savePushDay();
    final sessionId = await sessions.startSession(planId: id);

    await plans.deletePlan(id);

    expect(await plans.watchPlans().first, isEmpty);
    final session = await sessions.watchSession(sessionId).first;
    expect(session, isNotNull);
    expect(session?.planId, isNull);
  });
}
