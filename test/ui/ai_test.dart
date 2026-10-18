import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:loggym/app.dart';
import 'package:loggym/data/database/app_database.dart';
import 'package:loggym/data/database/database_provider.dart';
import 'package:loggym/data/services/ai_client.dart';
import 'package:loggym/data/services/wger_client.dart';
import 'package:loggym/domain/ai_provider.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));

  tearDown(() => database.close());

  void storeKey() => FlutterSecureStorage.setMockInitialValues({
    'ai_settings': jsonEncode(
      const AiSettings(
        provider: AiProvider.anthropic,
        apiKey: 'sk-ant-1234',
        model: 'claude-haiku-5-5',
      ).toJson(),
    ),
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    required MockClientHandler ai,
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          aiHttpClientProvider.overrideWithValue(MockClient(ai)),
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

  Future<void> typeNewExercise(WidgetTester tester, String title) async {
    await tester.tap(find.text('Exercises'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create your first exercise'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, title);
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
  }

  testWidgets('without a key the form offers no AI', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await pumpApp(tester, ai: (_) async => http.Response('', 500));
    await typeNewExercise(tester, 'Bulgarian split squat');

    expect(find.text('Fill with AI'), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('fills the exercise form and clear undoes it', (tester) async {
    storeKey();
    await pumpApp(
      tester,
      ai: (_) async => http.Response(
        jsonEncode({
          'content': [
            {
              'type': 'text',
              'text': jsonEncode({
                'recognized': true,
                'title': 'Bulgarian split squat',
                'trackingType': 'weightReps',
                'muscles': ['Quads', 'Glutes'],
                'formCues': ['Keep the torso upright'],
              }),
            },
          ],
        }),
        200,
      ),
    );
    await typeNewExercise(tester, 'bulgarian split sqaut');

    await tester.tap(find.text('Fill with AI'));
    await tester.pumpAndSettle();

    expect(find.text('Filled with AI'), findsOneWidget);
    expect(find.text('Bulgarian split squat'), findsOneWidget);
    expect(find.text('Keep the torso upright'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('bulgarian split sqaut'), findsOneWidget);
    expect(find.text('Keep the torso upright'), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('a failed fill explains why', (tester) async {
    storeKey();
    await pumpApp(tester, ai: (_) async => http.Response('{}', 401));
    await typeNewExercise(tester, 'Squat');

    await tester.tap(find.text('Fill with AI'));
    await tester.pumpAndSettle();

    expect(find.text('Anthropic did not accept the API key'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('saving a key checks it with the provider first', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    var accepted = false;
    await pumpApp(
      tester,
      ai: (request) async => http.Response('{}', accepted ? 200 : 401),
    );
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI provider'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'sk-wrong');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('OpenAI did not accept the API key'), findsOneWidget);

    accepted = true;
    await tester.enterText(find.byType(TextField).first, 'sk-right-9876');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('AI features are on'), findsOneWidget);
    expect(find.text('OpenAI · gpt-6-luna · key ending 9876'), findsOneWidget);

    await unmountApp(tester);
  });
}
