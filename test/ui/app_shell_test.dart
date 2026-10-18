import 'package:djym/app.dart';
import 'package:djym/data/database/app_database.dart';
import 'package:djym/data/database/database_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const DjymApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('opens on the calendar and navigates between tabs', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('djym'), findsOneWidget);

    await tester.tap(find.text('Plans'));
    await tester.pumpAndSettle();
    expect(find.text('Workout plans'), findsOneWidget);

    await tester.tap(find.text('Exercises'));
    await tester.pumpAndSettle();
    expect(find.text('No exercises yet'), findsOneWidget);

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('Theme'), findsOneWidget);

    await unmountApp(tester);
  });
}
