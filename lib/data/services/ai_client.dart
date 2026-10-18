import 'dart:async';
import 'dart:convert';

import 'package:djym/data/services/ai_settings_store.dart';
import 'package:djym/domain/ai_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

const _timeout = Duration(seconds: 45);
const _anthropicVersion = '2023-06-01';

class AiException implements Exception {
  const AiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Talks to the provider the user picked, each through its own REST API,
/// and always asks for JSON matching a schema.
class AiClient {
  const AiClient(this._http, this.settings);

  final http.Client _http;
  final AiSettings settings;

  AiProvider get _provider => settings.provider;

  Map<String, String> get _headers => switch (_provider) {
    AiProvider.openAi => {'authorization': 'Bearer ${settings.apiKey}'},
    AiProvider.anthropic => {
      'x-api-key': settings.apiKey,
      'anthropic-version': _anthropicVersion,
    },
    AiProvider.gemini => {'x-goog-api-key': settings.apiKey},
  };

  Uri get _modelUri => switch (_provider) {
    AiProvider.openAi => Uri.https(
      'api.openai.com',
      '/v1/models/${settings.model}',
    ),
    AiProvider.anthropic => Uri.https(
      'api.anthropic.com',
      '/v1/models/${settings.model}',
    ),
    AiProvider.gemini => Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/${settings.model}',
    ),
  };

  /// Checks the key and the model without generating anything.
  Future<void> verify() => _send(() => _http.get(_modelUri, headers: _headers));

  /// [schema] is plain JSON Schema with `additionalProperties: false` on
  /// every object, as OpenAI and Anthropic require.
  Future<Map<String, dynamic>> generateJson({
    required String instructions,
    required String prompt,
    required Map<String, dynamic> schema,
  }) async {
    final (uri, body) = switch (_provider) {
      AiProvider.openAi => (
        Uri.https('api.openai.com', '/v1/chat/completions'),
        {
          'model': settings.model,
          'messages': [
            {'role': 'developer', 'content': instructions},
            {'role': 'user', 'content': prompt},
          ],
          'response_format': {
            'type': 'json_schema',
            'json_schema': {'name': 'result', 'strict': true, 'schema': schema},
          },
        },
      ),
      AiProvider.anthropic => (
        Uri.https('api.anthropic.com', '/v1/messages'),
        {
          'model': settings.model,
          'max_tokens': 1024,
          'system': instructions,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'output_config': {
            'format': {'type': 'json_schema', 'schema': schema},
          },
        },
      ),
      AiProvider.gemini => (
        Uri.https(
          'generativelanguage.googleapis.com',
          '/v1beta/models/${settings.model}:generateContent',
        ),
        {
          'systemInstruction': {
            'parts': [
              {'text': instructions},
            ],
          },
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {
            'responseMimeType': 'application/json',
            'responseSchema': geminiSchema(schema),
          },
        },
      ),
    };

    final response = await _send(
      () => _http.post(
        uri,
        headers: {..._headers, 'content-type': 'application/json'},
        body: jsonEncode(body),
      ),
    );
    try {
      final json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return jsonDecode(_textOf(json)) as Map<String, dynamic>;
    } on Object {
      throw AiException("${_provider.label}'s answer could not be read");
    }
  }

  String _textOf(Map<String, dynamic> json) => switch ((_provider, json)) {
    (
      AiProvider.openAi,
      {
        'choices': [
          {'message': {'content': final String text}},
          ...,
        ],
      },
    ) =>
      text,
    (AiProvider.anthropic, {'content': final List<dynamic> blocks}) =>
      blocks.cast<Map<String, dynamic>>().firstWhere(
            (block) => block['type'] == 'text',
          )['text']
          as String,
    (
      AiProvider.gemini,
      {
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': final String text},
                ...,
              ],
            },
          },
          ...,
        ],
      },
    ) =>
      text,
    _ => throw const FormatException('Unexpected response'),
  };

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(_timeout);
    } on Exception {
      throw AiException("Couldn't reach ${_provider.label}");
    }
    final status = response.statusCode;
    if (status == 200) return response;

    final keyRejected =
        status == 401 ||
        status == 403 ||
        (status == 400 && response.body.contains('API_KEY_INVALID'));
    throw AiException(switch (status) {
      _ when keyRejected => '${_provider.label} did not accept the API key',
      404 => 'Model "${settings.model}" was not found',
      429 => '${_provider.label} rate limit or quota reached',
      _ => '${_provider.label} returned an error ($status)',
    });
  }
}

/// Gemini's response schema is an OpenAPI subset: upper-case types and no
/// `additionalProperties`.
Map<String, dynamic> geminiSchema(Map<String, dynamic> schema) => {
  for (final MapEntry(:key, :value) in schema.entries)
    if (key != 'additionalProperties')
      key: switch (value) {
        final String type when key == 'type' => type.toUpperCase(),
        final Map<String, dynamic> nested when key == 'properties' => {
          for (final MapEntry(:key, :value) in nested.entries)
            key: geminiSchema(value as Map<String, dynamic>),
        },
        final Map<String, dynamic> nested => geminiSchema(nested),
        _ => value,
      },
};

final aiHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Null until the user adds an API key, which keeps AI features hidden.
final aiClientProvider = Provider<AiClient?>((ref) {
  final settings = ref.watch(aiSettingsProvider).value;
  if (settings == null) return null;
  return AiClient(ref.watch(aiHttpClientProvider), settings);
});
