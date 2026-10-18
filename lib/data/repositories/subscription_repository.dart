import 'package:djym/data/database/app_database.dart';
import 'package:djym/data/database/database_provider.dart';
import 'package:djym/domain/subscription_period.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SubscriptionOverview {
  SubscriptionOverview(this.subscription, this.sessionCount)
    : period = SubscriptionPeriod(
        subscription.startDate,
        subscription.endDate,
      );

  final GymSubscription subscription;
  final SubscriptionPeriod period;

  /// Finished workouts that count towards this subscription.
  final int sessionCount;

  int? get costPerSessionCents => sessionCount == 0
      ? null
      : (subscription.costCents / sessionCount).round();
}

/// The subscriptions the Calendar shows, soonest ending first: every running
/// one, ones starting later that do not renew a running one, and ones that
/// ended in the last 30 days without being renewed.
List<SubscriptionOverview> featuredSubscriptions(
  List<SubscriptionOverview> subscriptions,
  DateTime today,
) {
  bool running(SubscriptionOverview overview) =>
      overview.period.hasStartedOn(today) && !overview.period.hasEndedOn(today);
  final runningTitles = {
    for (final overview in subscriptions.where(running))
      _titleKey(overview.subscription.title),
  };

  return [
    for (final overview in subscriptions)
      if (running(overview) ||
          (!overview.period.hasStartedOn(today) &&
              !runningTitles.contains(
                _titleKey(overview.subscription.title),
              )) ||
          (overview.period.hasEndedOn(today) &&
              overview.period.daysLeftOn(today) >= -30 &&
              !isRenewed(overview, subscriptions)))
        overview,
  ]..sort((a, b) => a.period.end.compareTo(b.period.end));
}

/// Whether a later subscription with the same name follows [overview].
bool isRenewed(
  SubscriptionOverview overview,
  List<SubscriptionOverview> subscriptions,
) => subscriptions.any(
  (other) =>
      _titleKey(other.subscription.title) ==
          _titleKey(overview.subscription.title) &&
      other.period.start.isAfter(overview.period.start),
);

String _titleKey(String title) => title.trim().toLowerCase();

class SubscriptionRepository {
  const SubscriptionRepository(this._database);

  final AppDatabase _database;

  $GymSubscriptionsTable get _subscriptions => _database.gymSubscriptions;
  $WorkoutSessionsTable get _sessions => _database.workoutSessions;

  /// Latest start first. Reloads when workouts change, since they are counted.
  Stream<List<SubscriptionOverview>> watchSubscriptions() async* {
    yield await loadSubscriptions();
    await for (final _ in _database.tableUpdates(
      TableUpdateQuery.onAllTables([_subscriptions, _sessions]),
    )) {
      yield await loadSubscriptions();
    }
  }

  Future<List<SubscriptionOverview>> loadSubscriptions() async {
    final count = _sessions.id.count();
    final countRows =
        await (_database.selectOnly(_sessions)
              ..addColumns([_sessions.subscriptionId, count])
              ..where(
                _sessions.subscriptionId.isNotNull() &
                    _sessions.finishedAt.isNotNull(),
              )
              ..groupBy([_sessions.subscriptionId]))
            .get();
    final counts = {
      for (final row in countRows)
        row.read(_sessions.subscriptionId)!: row.read(count)!,
    };

    return [
      for (final subscription in await _newestFirst().get())
        SubscriptionOverview(subscription, counts[subscription.id] ?? 0),
    ];
  }

  SimpleSelectStatement<$GymSubscriptionsTable, GymSubscription>
  _newestFirst() => _database.select(_subscriptions)
    ..orderBy([
      (row) => OrderingTerm.desc(row.startDate),
      (row) => OrderingTerm.desc(row.id),
    ]);

  /// Subscriptions running at [moment], latest start first.
  Future<List<GymSubscription>> subscriptionsCovering(DateTime moment) async =>
      [
        for (final subscription in await _newestFirst().get())
          if (SubscriptionPeriod(
            subscription.startDate,
            subscription.endDate,
          ).contains(moment))
            subscription,
      ];

  Future<void> linkSession(int sessionId, int? subscriptionId) =>
      (_database.update(
        _sessions,
      )..where((row) => row.id.equals(sessionId))).write(
        WorkoutSessionsCompanion(subscriptionId: Value(subscriptionId)),
      );

  /// Links a just finished workout to the subscription running on its day.
  /// With several running, the one picked most recently among them wins.
  Future<void> linkToLikelySubscription(WorkoutSession session) async {
    final covering = await subscriptionsCovering(session.startedAt);
    if (covering.isEmpty) return;

    final ids = [for (final subscription in covering) subscription.id];
    final lastPicked =
        await (_database.select(_sessions)
              ..where(
                (row) =>
                    row.subscriptionId.isIn(ids) &
                    row.id.equals(session.id).not(),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.startedAt)])
              ..limit(1))
            .getSingleOrNull();
    await linkSession(session.id, lastPicked?.subscriptionId ?? ids.first);
  }

  Future<int> saveSubscription({
    required String title,
    required int costCents,
    required SubscriptionPeriod period,
    int? id,
  }) async {
    final row = GymSubscriptionsCompanion(
      id: Value.absentIfNull(id),
      title: Value(title),
      costCents: Value(costCents),
      startDate: Value(period.start),
      endDate: Value(period.end),
    );
    final insertedId = await _subscriptions.insertOnConflictUpdate(row);
    if (id != null) return id;

    await _linkUnassignedSessionsTo(insertedId);
    return insertedId;
  }

  /// A subscription added after the fact picks up the workouts it alone
  /// covers.
  Future<void> _linkUnassignedSessionsTo(int subscriptionId) async {
    final unassigned =
        await (_database.select(_sessions)..where(
              (row) => row.subscriptionId.isNull() & row.finishedAt.isNotNull(),
            ))
            .get();
    for (final session in unassigned) {
      final covering = await subscriptionsCovering(session.startedAt);
      if (covering.length == 1 && covering.single.id == subscriptionId) {
        await linkSession(session.id, subscriptionId);
      }
    }
  }

  /// Returns the workouts that counted for it, so undo can link them again.
  Future<List<int>> deleteSubscription(int id) =>
      _database.transaction(() async {
        final linked =
            await (_database.selectOnly(_sessions)
                  ..addColumns([_sessions.id])
                  ..where(_sessions.subscriptionId.equals(id)))
                .map((row) => row.read(_sessions.id)!)
                .get();
        await (_database.delete(
          _subscriptions,
        )..where((row) => row.id.equals(id))).go();
        return linked;
      });

  Future<void> restoreSubscription(
    GymSubscription subscription,
    List<int> sessionIds,
  ) => _database.transaction(() async {
    await _subscriptions.insertOne(subscription);
    await (_database.update(
      _sessions,
    )..where((row) => row.id.isIn(sessionIds))).write(
      WorkoutSessionsCompanion(subscriptionId: Value(subscription.id)),
    );
  });
}

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (ref) => SubscriptionRepository(ref.watch(appDatabaseProvider)),
);

final subscriptionsProvider = StreamProvider<List<SubscriptionOverview>>(
  (ref) => ref.watch(subscriptionRepositoryProvider).watchSubscriptions(),
);
