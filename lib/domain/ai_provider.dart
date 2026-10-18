enum AiProvider {
  openAi(
    label: 'OpenAI',
    defaultModel: 'gpt-6-luna',
    keysPage: 'platform.openai.com/api-keys',
  ),
  anthropic(
    label: 'Anthropic',
    defaultModel: 'claude-haiku-5-5',
    keysPage: 'platform.claude.com/settings/keys',
  ),
  gemini(
    label: 'Gemini',
    defaultModel: 'gemini-3.8-flash',
    keysPage: 'aistudio.google.com/apikey',
  )
  ;

  const AiProvider({
    required this.label,
    required this.defaultModel,
    required this.keysPage,
  });

  final String label;
  final String defaultModel;
  final String keysPage;
}

class AiSettings {
  const AiSettings({
    required this.provider,
    required this.apiKey,
    required this.model,
  });

  factory AiSettings.fromJson(Map<String, dynamic> json) => AiSettings(
    provider: AiProvider.values.byName(json['provider'] as String),
    apiKey: json['apiKey'] as String,
    model: json['model'] as String,
  );

  final AiProvider provider;
  final String apiKey;
  final String model;

  /// The last four characters, enough to tell keys apart.
  String get keyHint =>
      apiKey.length <= 4 ? apiKey : apiKey.substring(apiKey.length - 4);

  Map<String, dynamic> toJson() => {
    'provider': provider.name,
    'apiKey': apiKey,
    'model': model,
  };
}
