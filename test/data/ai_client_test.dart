import 'dart:convert';

import 'package:djym/data/services/ai_client.dart';
import 'package:djym/domain/ai_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const schema = {
    'type': 'object',
    'properties': {
      'name': {'type': 'string'},
      'tags': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
    'required': ['name', 'tags'],
    'additionalProperties': false,
  };
  const answer = '{"name": "Squat", "tags": []}';

  late http.Request sent;

  AiClient clientFor(AiProvider provider, Map<String, dynamic> response) =>
      AiClient(
        MockClient((request) async {
          sent = request;
          return http.Response(jsonEncode(response), 200);
        }),
        AiSettings(provider: provider, apiKey: 'secret', model: 'm1'),
      );

  Future<Map<String, dynamic>> generate(AiClient client) => client.generateJson(
    instructions: 'Be brief',
    prompt: 'Squat',
    schema: schema,
  );

  Map<String, dynamic> sentBody() =>
      jsonDecode(sent.body) as Map<String, dynamic>;

  test('OpenAI uses chat completions with a strict JSON schema', () async {
    final client = clientFor(AiProvider.openAi, {
      'choices': [
        {
          'message': {'content': answer},
        },
      ],
    });

    expect(await generate(client), {'name': 'Squat', 'tags': <String>[]});
    expect(sent.url.toString(), 'https://api.openai.com/v1/chat/completions');
    expect(sent.headers['authorization'], 'Bearer secret');
    expect(sentBody()['response_format'], {
      'type': 'json_schema',
      'json_schema': {'name': 'result', 'strict': true, 'schema': schema},
    });
  });

  test('Anthropic uses messages with an output format', () async {
    final client = clientFor(AiProvider.anthropic, {
      'content': [
        {'type': 'text', 'text': answer},
      ],
    });

    expect((await generate(client))['name'], 'Squat');
    expect(sent.url.toString(), 'https://api.anthropic.com/v1/messages');
    expect(sent.headers['x-api-key'], 'secret');
    expect(sent.headers['anthropic-version'], '2023-06-01');
    expect(sentBody()['system'], 'Be brief');
    expect(sentBody()['output_config'], {
      'format': {'type': 'json_schema', 'schema': schema},
    });
  });

  test('Gemini gets its own schema dialect', () async {
    final client = clientFor(AiProvider.gemini, {
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': answer},
            ],
          },
        },
      ],
    });

    expect((await generate(client))['name'], 'Squat');
    expect(
      sent.url.toString(),
      'https://generativelanguage.googleapis.com/v1beta/models/m1:generateContent',
    );
    expect(sent.headers['x-goog-api-key'], 'secret');
    expect((sentBody()['generationConfig'] as Map)['responseSchema'], {
      'type': 'OBJECT',
      'properties': {
        'name': {'type': 'STRING'},
        'tags': {
          'type': 'ARRAY',
          'items': {'type': 'STRING'},
        },
      },
      'required': ['name', 'tags'],
    });
  });

  test('verify looks up the model', () async {
    await clientFor(AiProvider.anthropic, {}).verify();

    expect(sent.method, 'GET');
    expect(sent.url.toString(), 'https://api.anthropic.com/v1/models/m1');
  });

  group('errors read as plain sentences', () {
    Future<String> messageFor(
      AiProvider provider,
      int status, [
      String body = '{}',
    ]) async {
      final client = AiClient(
        MockClient((_) async => http.Response(body, status)),
        AiSettings(provider: provider, apiKey: 'bad', model: 'm1'),
      );
      try {
        await client.verify();
      } on AiException catch (error) {
        return error.message;
      }
      fail('verify should throw');
    }

    test('a rejected key', () async {
      expect(
        await messageFor(AiProvider.openAi, 401),
        'OpenAI did not accept the API key',
      );
      expect(
        await messageFor(
          AiProvider.gemini,
          400,
          '{"reason":"API_KEY_INVALID"}',
        ),
        'Gemini did not accept the API key',
      );
    });

    test('an unknown model', () async {
      expect(
        await messageFor(AiProvider.anthropic, 404),
        'Model "m1" was not found',
      );
    });

    test('an unreadable answer', () async {
      final client = clientFor(AiProvider.openAi, {'choices': <Object>[]});

      expect(
        () => generate(client),
        throwsA(
          isA<AiException>().having(
            (error) => error.message,
            'message',
            "OpenAI's answer could not be read",
          ),
        ),
      );
    });
  });
}
