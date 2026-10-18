import 'dart:convert';

import 'package:djym/data/services/ai_client.dart';
import 'package:djym/data/services/exercise_autofill.dart';
import 'package:djym/domain/ai_provider.dart';
import 'package:djym/domain/tracking_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  AiClient answering(Map<String, dynamic> draft) => AiClient(
    MockClient(
      (_) async => http.Response(
        jsonEncode({
          'content': [
            {'type': 'text', 'text': jsonEncode(draft)},
          ],
        }),
        200,
      ),
    ),
    const AiSettings(
      provider: AiProvider.anthropic,
      apiKey: 'key',
      model: 'm1',
    ),
  );

  test('turns the answer into a draft of known muscles', () async {
    final draft = await draftExercise(
      answering({
        'recognized': true,
        'title': 'Bulgarian split squat',
        'trackingType': 'weightReps',
        'muscles': ['Quads', 'Glutes', 'Adductors', 'Quads'],
        'formCues': ['Keep the torso upright', 'Drive through the front heel'],
      }),
      title: 'bulgarian split sqaut',
      muscleNames: const ['Glutes', 'Hamstrings', 'Quads'],
    );

    expect(draft.title, 'Bulgarian split squat');
    expect(draft.trackingType, TrackingType.weightReps);
    expect(draft.muscleNames, ['Quads', 'Glutes']);
    expect(
      draft.formGuidance,
      'Keep the torso upright\nDrive through the front heel',
    );
  });

  test('refuses names that are not exercises', () async {
    final client = answering({
      'recognized': false,
      'title': 'Banana',
      'trackingType': 'reps',
      'muscles': <String>[],
      'formCues': <String>[],
    });

    expect(
      () => draftExercise(client, title: 'banana', muscleNames: const []),
      throwsA(isA<AiException>()),
    );
  });
}
