import 'package:djym/data/services/ai_client.dart';
import 'package:djym/data/services/ai_settings_store.dart';
import 'package:djym/domain/ai_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AiSettingsScreen extends ConsumerWidget {
  const AiSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(aiSettingsProvider);
    if (settings.isLoading) return const Scaffold();
    return _AiSettingsForm(existing: settings.value);
  }
}

class _AiSettingsForm extends ConsumerStatefulWidget {
  const _AiSettingsForm({this.existing});

  final AiSettings? existing;

  @override
  ConsumerState<_AiSettingsForm> createState() => _AiSettingsFormState();
}

class _AiSettingsFormState extends ConsumerState<_AiSettingsForm> {
  late AiProvider _provider = widget.existing?.provider ?? AiProvider.openAi;
  late final _apiKey = TextEditingController(text: widget.existing?.apiKey);
  late final _model = TextEditingController(
    text: widget.existing?.model ?? _provider.defaultModel,
  );
  var _showKey = false;
  var _checking = false;
  String? _error;

  @override
  void dispose() {
    _apiKey.dispose();
    _model.dispose();
    super.dispose();
  }

  void _selectProvider(AiProvider provider) {
    if (_model.text.trim() == _provider.defaultModel) {
      _model.text = provider.defaultModel;
    }
    setState(() {
      _provider = provider;
      _error = null;
    });
  }

  Future<void> _save() async {
    final settings = AiSettings(
      provider: _provider,
      apiKey: _apiKey.text.trim(),
      model: _model.text.trim().isEmpty
          ? _provider.defaultModel
          : _model.text.trim(),
    );
    if (settings.apiKey.isEmpty) {
      setState(() => _error = 'Paste your API key');
      return;
    }

    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      await AiClient(ref.read(aiHttpClientProvider), settings).verify();
    } on AiException catch (error) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = error.message;
      });
      return;
    }
    if (!mounted) return;

    await ref.read(aiSettingsProvider.notifier).save(settings);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('AI features are on')));
    context.pop();
  }

  Future<void> _remove() async {
    await ref.read(aiSettingsProvider.notifier).clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API key removed, AI features are off')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quiet = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI assistant'),
        actions: [
          TextButton(
            onPressed: _checking ? null : _save,
            child: const Text('Save'),
          ),
        ],
        bottom: _checking
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Add an API key from your own account to turn on AI features, '
            'like filling in a new exercise from its name. Requests go '
            'straight from this phone to the provider and are billed to you.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          SegmentedButton<AiProvider>(
            showSelectedIcon: false,
            segments: [
              for (final provider in AiProvider.values)
                ButtonSegment(value: provider, label: Text(provider.label)),
            ],
            selected: {_provider},
            onSelectionChanged: (selected) => _selectProvider(selected.single),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _apiKey,
            obscureText: !_showKey,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: '${_provider.label} API key',
              helperText: 'Create one at ${_provider.keysPage}',
              helperMaxLines: 2,
              errorText: _error,
              errorMaxLines: 3,
              suffixIcon: IconButton(
                tooltip: _showKey ? 'Hide key' : 'Show key',
                icon: Icon(
                  _showKey ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => _showKey = !_showKey),
              ),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _model,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Model',
              helperText: 'Default: ${_provider.defaultModel}',
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Icon(
                Icons.lock_outline,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              Expanded(
                child: Text(
                  'Your key is stored encrypted on this phone and is never '
                  'included in backups.',
                  style: quiet,
                ),
              ),
            ],
          ),
          if (widget.existing != null) ...[
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _checking ? null : _remove,
              icon: const Icon(Icons.key_off_outlined),
              label: const Text('Remove key'),
            ),
          ],
        ],
      ),
    );
  }
}
