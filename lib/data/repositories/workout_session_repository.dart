import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:loggym/data/database/app_database.dart';
import 'package:loggym/data/database/database_provider.dart';

class WorkoutSessionRepository {
  const WorkoutSessionRepository(this._database);

  final AppDatabase _database;

  Stream<List<WorkoutSession>> watchSessionsInMonth(DateTime month) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final query = _database.select(_database.workoutSessions)
      ..where(
        (session) =>
            session.startedAt.isBiggerOrEqualValue(start) &
            session.startedAt.isSmallerThanValue(end),
      )
      ..orderBy([(session) => OrderingTerm.asc(session.startedAt)]);
    return query.watch();
  }
}

final workoutSessionRepositoryProvider = Provider<WorkoutSessionRepository>(
  (ref) => WorkoutSessionRepository(ref.watch(appDatabaseProvider)),
);

final StreamProviderFamily<List<WorkoutSession>, DateTime>
sessionsInMonthProvider = StreamProvider.family<List<WorkoutSession>, DateTime>(
  (ref, month) =>
      ref.watch(workoutSessionRepositoryProvider).watchSessionsInMonth(month),
);
