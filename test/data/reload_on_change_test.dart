import 'dart:async';

import 'package:djym/data/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('streams over different tables reload independently', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    var planLoads = 0;
    final subscriptions = database
        .reloadOnChange({database.gymSubscriptions}, () async => 0)
        .listen((_) {});
    final plans = StreamIterator(
      database.reloadOnChange({database.workoutPlans}, () async => ++planLoads),
    );

    await plans.moveNext();
    expect(plans.current, 1);

    await database
        .into(database.workoutPlans)
        .insert(WorkoutPlansCompanion.insert(name: 'Push'));
    await plans.moveNext();
    expect(plans.current, 2);

    await plans.cancel();
    await subscriptions.cancel();
  });
}
