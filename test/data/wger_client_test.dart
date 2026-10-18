import 'dart:io';

import 'package:djym/data/services/wger_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final fixture = File(
    'test/fixtures/wger_search_bench_press.json',
  ).readAsBytesSync();

  test('searches English exercises by name', () async {
    late Uri requested;
    final client = WgerClient(
      MockClient((request) async {
        requested = request.url;
        return http.Response.bytes(fixture, 200);
      }),
    );

    final results = await client.search('bench press');

    expect(requested.path, '/api/v2/exerciseinfo/');
    expect(requested.queryParameters, containsPair('language__code', 'en'));
    expect(
      requested.queryParameters,
      containsPair('name__search', 'bench press'),
    );
    expect(results.map((exercise) => exercise.name), [
      'Bench Press',
      'Bench Press Isometric',
      'Bench Press Narrow Grip',
    ]);
  });

  test('maps primary then secondary muscles to local names', () async {
    final [bench, isometric, _] = await WgerClient(
      MockClient((_) async => http.Response.bytes(fixture, 200)),
    ).search('bench press');

    expect(bench.muscleNames, ['Chest', 'Shoulders', 'Triceps']);
    expect(isometric.muscleNames, [
      'Shoulders',
      'Chest',
      'Triceps',
      'Obliques',
      'Abs',
    ]);
  });

  test('turns the HTML description into plain text', () async {
    final [bench, _, narrowGrip] = await WgerClient(
      MockClient((_) async => http.Response.bytes(fixture, 200)),
    ).search('bench press');

    expect(bench.description, startsWith('Lay down on a bench'));
    expect(narrowGrip.description, startsWith('• Setup: Lie flat'));
    expect(narrowGrip.description, isNot(contains('<')));
  });

  test('uses the small thumbnail of the main image', () async {
    final [bench, isometric, _] = await WgerClient(
      MockClient((_) async => http.Response.bytes(fixture, 200)),
    ).search('bench press');

    expect(
      bench.thumbnailUrl,
      'https://wger.de/media/exercise-images/192/Bench-press-1.png.200x200_q85.png',
    );
    expect(isometric.thumbnailUrl, isNull);
    expect(bench.externalId, startsWith('wger:'));
  });

  test('throws when wger does not answer with 200', () async {
    final client = WgerClient(
      MockClient((_) async => http.Response('down', 503)),
    );

    expect(client.search('squat'), throwsA(isA<http.ClientException>()));
  });
}
