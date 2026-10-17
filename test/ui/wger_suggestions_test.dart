import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:loggym/app.dart';
import 'package:loggym/data/database/app_database.dart';
import 'package:loggym/data/database/database_provider.dart';
import 'package:loggym/data/repositories/exercise_repository.dart';
import 'package:loggym/data/services/wger_client.dart';
import 'package:loggym/domain/tracking_type.dart';

void main() {
  final fixture = File(
    'test/fixtures/wger_search_bench_press.json',
  ).readAsBytesSync();
  final onlineWger = MockClient(
    (request) async => request.url.path == '/api/v2/exerciseinfo/'
        ? http.Response.bytes(fixture, 200)
        : http.Response.bytes([1, 2, 3], 200),
  );
  late AppDatabase database;
  late ExerciseRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = ExerciseRepository(database);
  });

  tearDown(() => database.close());

  Future<void> openNewExerciseForm(
    WidgetTester tester, {
    http.Client? wger,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          wgerClientProvider.overrideWithValue(WgerClient(wger ?? onlineWger)),
        ],
        child: const LogGymApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exercises'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
  }

  Future<void> typeTitle(WidgetTester tester, String title) async {
    await tester.enterText(find.byType(TextFormField).first, title);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('a picked suggestion prefills the form and is saved with its '
      'wger link and thumbnail', (tester) async {
    await openNewExerciseForm(tester);

    await typeTitle(tester, 'bench');
    expect(find.text('Suggestions from wger · 3'), findsOneWidget);

    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();

    expect(find.text('Prefilled from wger'), findsOneWidget);
    expect(find.textContaining('Suggestions from wger'), findsNothing);
    expect(
      find.widgetWithText(TextFormField, 'Bench Press'),
      findsOneWidget,
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final rows = await database.select(database.exercises).get();
    expect(rows.single.title, 'Bench Press');
    expect(rows.single.externalId, startsWith('wger:'));
    expect(
      await repository.thumbnail(rows.single.id),
      [1, 2, 3],
      reason: 'the downloaded wger thumbnail is stored with the exercise',
    );
    expect(find.text('Chest, Shoulders, Triceps'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('clear restores what was typed before the prefill', (
    tester,
  ) async {
    await openNewExerciseForm(tester);

    await typeTitle(tester, 'bench');
    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'bench'), findsOneWidget);
    expect(find.text('Prefilled from wger'), findsNothing);
    expect(find.text('Suggestions from wger · 3'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('marks suggestions already in the library', (tester) async {
    await repository.saveExercise(
      title: 'Bench Press',
      trackingType: TrackingType.weightReps,
      muscleIds: const [],
      externalId: 'wger:3717d144-7815-4a97-9a56-956fb889c996',
    );
    await openNewExerciseForm(tester);

    await typeTitle(tester, 'bench');

    expect(find.text('In library'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('offline shows a quiet note and saving by hand still works', (
    tester,
  ) async {
    await openNewExerciseForm(
      tester,
      wger: MockClient((_) async => throw http.ClientException('offline')),
    );

    await typeTitle(tester, 'bench');

    expect(
      find.text('wger suggestions are unavailable right now'),
      findsOneWidget,
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('bench'), findsOneWidget);

    await unmountApp(tester);
  });
}
