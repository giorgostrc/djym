import 'package:djym/data/database/app_database.dart';
import 'package:djym/data/repositories/subscription_repository.dart';
import 'package:djym/data/repositories/workout_session_repository.dart';
import 'package:djym/domain/subscription_period.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late SubscriptionRepository subscriptions;
  late WorkoutSessionRepository sessions;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    subscriptions = SubscriptionRepository(database);
    sessions = WorkoutSessionRepository(database);
  });

  tearDown(() => database.close());

  Future<void> save(String title, DateTime start, int months) =>
      subscriptions.saveSubscription(
        title: title,
        costCents: 6000,
        period: SubscriptionPeriod.months(start, months),
      );

  test('cost per session divides by workouts inside the period', () async {
    await save('City Gym', DateTime(2026, 10), 1);
    await sessions.logPastSession(DateTime(2026, 10));
    await sessions.logPastSession(DateTime(2026, 10, 15));
    await sessions.logPastSession(DateTime(2026, 10, 31));
    await sessions.logPastSession(DateTime(2026, 11));

    final [city] = await subscriptions.loadSubscriptions();

    expect(city.sessionCount, 3);
    expect(city.costPerSessionCents, 2000);
  });

  test('a period without workouts has no cost per session', () async {
    await save('City Gym', DateTime(2026, 10), 1);
    await sessions.logPastSession(DateTime(2026, 9, 30));

    final [city] = await subscriptions.loadSubscriptions();

    expect(city.sessionCount, 0);
    expect(city.costPerSessionCents, isNull);
  });

  test('with overlapping subscriptions a workout counts for one, the last '
      'picked', () async {
    await save('Yearly', DateTime(2026), 12);
    await save('Pool', DateTime(2026, 10), 1);
    final march = await sessions.logPastSession(DateTime(2026, 3, 3));
    final october = await sessions.logPastSession(DateTime(2026, 10, 3));

    var [pool, yearly] = await subscriptions.loadSubscriptions();
    expect(yearly.sessionCount, 2);
    expect(pool.sessionCount, 0);

    await subscriptions.linkSession(october, pool.subscription.id);
    final later = await sessions.logPastSession(DateTime(2026, 10, 4));

    [pool, yearly] = await subscriptions.loadSubscriptions();
    expect(yearly.sessionCount, 1);
    expect(pool.sessionCount, 2);
    expect(yearly.costPerSessionCents, 6000);
    expect(
      (await sessions.watchSession(later).first)?.subscriptionId,
      pool.subscription.id,
    );
    expect(
      (await sessions.watchSession(march).first)?.subscriptionId,
      yearly.subscription.id,
    );
  });

  test(
    'a subscription added later picks up the workouts only it covers',
    () async {
      await sessions.logPastSession(DateTime(2026, 10, 3));
      await sessions.logPastSession(DateTime(2026, 11, 3));

      await save('City Gym', DateTime(2026, 10), 1);

      final [city] = await subscriptions.loadSubscriptions();
      expect(city.sessionCount, 1);
    },
  );

  test('undoing a delete links its workouts again', () async {
    await save('City Gym', DateTime(2026, 10), 1);
    await sessions.logPastSession(DateTime(2026, 10, 3));
    final [city] = await subscriptions.loadSubscriptions();

    final linked = await subscriptions.deleteSubscription(city.subscription.id);
    expect(await subscriptions.loadSubscriptions(), isEmpty);

    await subscriptions.restoreSubscription(city.subscription, linked);
    final [restored] = await subscriptions.loadSubscriptions();
    expect(restored.sessionCount, 1);
  });

  test('a running workout is not counted until it is finished', () async {
    final now = DateTime.now();
    await save('City Gym', DateTime(now.year, now.month), 1);
    await sessions.startSession();

    final [city] = await subscriptions.loadSubscriptions();

    expect(city.sessionCount, 0);
  });

  test('the calendar shows every running subscription, soonest ending first, '
      'and ended ones until renewed', () {
    final today = DateTime(2026, 10, 18);
    var nextId = 0;
    SubscriptionOverview overview(String title, DateTime start, int months) =>
        SubscriptionOverview(
          GymSubscription(
            id: nextId++,
            title: title,
            costCents: 0,
            startDate: start,
            endDate: SubscriptionPeriod.months(start, months).end,
          ),
          0,
        );
    final gymRenewal = overview('Gym', DateTime(2026, 11), 1);
    final gym = overview('Gym', DateTime(2026, 10), 1);
    final yoga = overview('Yoga', DateTime(2026, 10, 10), 3);
    final runningClub = overview('Running club', DateTime(2026, 9), 1);
    final pool = overview('Pool', DateTime(2026, 11, 5), 1);
    final old = overview('Old', DateTime(2026), 1);
    final all = [pool, gymRenewal, yoga, gym, runningClub, old];

    expect(featuredSubscriptions(all, today), [runningClub, gym, pool, yoga]);
    expect(isRenewed(gym, all), isTrue);
    expect(isRenewed(yoga, all), isFalse);
    expect(featuredSubscriptions([old], today), isEmpty);
  });

  test('editing keeps the id', () async {
    await save('City Gym', DateTime(2026, 10), 1);
    final [city] = await subscriptions.loadSubscriptions();

    final id = await subscriptions.saveSubscription(
      id: city.subscription.id,
      title: 'City Gym Plus',
      costCents: 7000,
      period: city.period,
    );

    final [edited] = await subscriptions.loadSubscriptions();
    expect(id, city.subscription.id);
    expect(edited.subscription.title, 'City Gym Plus');
  });
}
