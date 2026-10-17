import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:http/http.dart' as http;

const _englishLanguageId = 2;

/// wger muscle ids mapped to the local muscle names; Serratus anterior (3)
/// has no local counterpart.
const _localMuscleByWgerId = {
  1: 'Biceps',
  2: 'Shoulders',
  4: 'Chest',
  5: 'Triceps',
  6: 'Abs',
  7: 'Calves',
  8: 'Glutes',
  9: 'Traps',
  10: 'Quads',
  11: 'Hamstrings',
  12: 'Lats',
  13: 'Biceps',
  14: 'Obliques',
  15: 'Calves',
};

class WgerExercise {
  const WgerExercise({
    required this.uuid,
    required this.name,
    required this.muscleNames,
    this.description,
    this.thumbnailUrl,
  });

  factory WgerExercise.fromJson(Map<String, dynamic> json) {
    final translations = (json['translations'] as List)
        .cast<Map<String, dynamic>>();
    final english = translations.firstWhere(
      (translation) => translation['language'] == _englishLanguageId,
    );
    final images = (json['images'] as List).cast<Map<String, dynamic>>();
    final image =
        images.where((image) => image['is_main'] == true).firstOrNull ??
        images.firstOrNull;
    final muscles = [
      ...json['muscles'] as List,
      ...json['muscles_secondary'] as List,
    ].cast<Map<String, dynamic>>();

    return WgerExercise(
      uuid: json['uuid'] as String,
      name: (english['name'] as String).trim(),
      description: _plainText(english['description'] as String),
      muscleNames: {
        for (final muscle in muscles)
          ?_localMuscleByWgerId[muscle['id'] as int],
      }.toList(),
      thumbnailUrl: (image?['thumbnails'] as Map?)?['small'] as String?,
    );
  }

  final String uuid;
  final String name;
  final String? description;
  final List<String> muscleNames;
  final String? thumbnailUrl;

  String get externalId => 'wger:$uuid';
}

class WgerClient {
  const WgerClient(this._http);

  final http.Client _http;

  Future<List<WgerExercise>> search(String term) async {
    final uri = Uri.https('wger.de', '/api/v2/exerciseinfo/', {
      'language__code': 'en',
      'name__search': term,
      'limit': '30',
    });
    final response = await _http.get(uri);
    if (response.statusCode != 200) {
      throw http.ClientException('wger returned ${response.statusCode}', uri);
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
    return [
      for (final json in body['results'] as List)
        WgerExercise.fromJson(json as Map<String, dynamic>),
    ];
  }

  Future<Uint8List> download(String url) => _http.readBytes(Uri.parse(url));
}

String? _plainText(String html) {
  final text = html
      .replaceAll(RegExp('<li[^>]*>'), '• ')
      .replaceAll(RegExp(r'</(p|li|h\d)>|<br\s*/?>'), '\n')
      .replaceAll(RegExp('<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');
  final lines = [
    for (final line in text.split('\n'))
      if (line.trim().isNotEmpty) line.trim(),
  ];
  return lines.isEmpty ? null : lines.join('\n');
}

final wgerClientProvider = Provider<WgerClient>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return WgerClient(client);
});

final FutureProviderFamily<List<WgerExercise>, String> wgerSearchProvider =
    FutureProvider.autoDispose.family<List<WgerExercise>, String>(
      (ref, term) => ref.watch(wgerClientProvider).search(term),
      retry: (_, _) => null,
    );
