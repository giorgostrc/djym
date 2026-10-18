import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loggym/app.dart';
import 'package:loggym/data/database/app_database.dart';
import 'package:loggym/data/database/database_provider.dart';
import 'package:loggym/data/repositories/exercise_repository.dart';
import 'package:loggym/data/repositories/subscription_repository.dart';
import 'package:loggym/data/repositories/workout_session_repository.dart';
import 'package:loggym/data/services/rest_alerts.dart';
import 'package:loggym/domain/subscription_period.dart';
import 'package:loggym/domain/tracking_type.dart';
import 'package:loggym/ui/core/clock_provider.dart';
import 'package:loggym/ui/core/keep_screen_on.dart';

import '../fakes/fake_rest_alerts.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));

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
          restAlertsProvider.overrideWithValue(FakeRestAlerts()),
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

  DateTime daysFromToday(int days) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + days);
  }

  Future<List<GymSubscription>> savedSubscriptions() =>
      database.select(database.gymSubscriptions).get();

  testWidgets('the first subscription is added from the calendar', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Track your gym subscription'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Gym'), 'City');
    await tester.enterText(find.widgetWithText(TextFormField, 'Cost'), '60');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('City'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('€60.00'), findsOneWidget);

    final [saved] = await savedSubscriptions();
    expect(saved.costCents, 6000);
    expect(
      SubscriptionPeriod(saved.startDate, saved.endDate).wholeMonths,
      1,
    );

    await unmountApp(tester);
  });

  testWidgets('a subscription about to end can be renewed', (tester) async {
    await SubscriptionRepository(database).saveSubscription(
      title: 'City',
      costCents: 6000,
      period: SubscriptionPeriod(daysFromToday(-10), daysFromToday(3)),
    );
    await pumpApp(tester);

    expect(find.text('Ends in 3 days'), findsOneWidget);

    await tester.tap(find.text('Renew'));
    await tester.pumpAndSettle();

    expect(find.text('Renew subscription'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Renew'), findsNothing);
    final [_, renewal] = await savedSubscriptions();
    expect(renewal.title, 'City');
    expect(dateOnly(renewal.startDate), daysFromToday(4));
    expect(
      SubscriptionPeriod(renewal.startDate, renewal.endDate).lengthInDays,
      14,
    );

    await unmountApp(tester);
  });

  testWidgets('a deleted subscription comes back on undo', (tester) async {
    await SubscriptionRepository(database).saveSubscription(
      title: 'City',
      costCents: 6000,
      period: SubscriptionPeriod.months(daysFromToday(-3), 1),
    );
    await pumpApp(tester);

    await tester.tap(find.text('City'));
    await tester.pumpAndSettle();

    expect(find.text('Gym subscriptions'), findsOneWidget);
    expect(find.text('Current'), findsOneWidget);

    await tester.tap(find.text('City'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Subscription options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete subscription'));
    await tester.pumpAndSettle();

    expect(find.text('No gym subscriptions yet'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('Current'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('finishing while two subscriptions run asks which one counts', (
    tester,
  ) async {
    final repository = SubscriptionRepository(database);
    for (final title in ['Gym', 'Yoga']) {
      await repository.saveSubscription(
        title: title,
        costCents: 6000,
        period: SubscriptionPeriod.months(daysFromToday(-3), 1),
      );
    }
    final squat = await ExerciseRepository(database).saveExercise(
      title: 'Squat',
      trackingType: TrackingType.weightReps,
      muscleIds: const [],
    );
    final sessions = WorkoutSessionRepository(database);
    final sessionId = await sessions.startSession();
    await sessions.addExercises(sessionId, [squat]);
    await database
        .update(database.exerciseSets)
        .write(const ExerciseSetsCompanion(reps: Value(5)));
    await pumpApp(tester);

    await tester.tap(find.textContaining('Workout in progress'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();

    expect(find.text('Counts towards'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Yoga'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();

    final [yoga, gym] = await repository.loadSubscriptions();
    expect(yoga.subscription.title, 'Yoga');
    expect(yoga.sessionCount, 1);
    expect(gym.sessionCount, 0);

    await unmountApp(tester);
  });
}
