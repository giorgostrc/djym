import 'package:djym/data/repositories/settings_repository.dart';
import 'package:djym/data/services/ai_settings_store.dart';
import 'package:djym/data/services/error_log.dart';
import 'package:djym/domain/theme_preference.dart';
import 'package:djym/domain/unit_system.dart';
import 'package:djym/routing/routes.dart';
import 'package:djym/ui/settings/backup_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

const _currencies = [
  'EUR',
  'USD',
  'GBP',
  'CHF',
  'SEK',
  'NOK',
  'DKK',
  'PLN',
  'CZK',
  'HUF',
  'RON',
  'BGN',
  'TRY',
  'CAD',
  'AUD',
  'JPY',
];

const _restLengths = [0, 30, 60, 90, 120, 150, 180, 240, 300];

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    final repository = ref.watch(settingsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settings == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                const _SectionHeader('Appearance'),
                ListTile(
                  title: const Text('Theme'),
                  subtitle: SegmentedButton<ThemePreference>(
                    segments: const [
                      ButtonSegment(
                        value: ThemePreference.system,
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: ThemePreference.light,
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemePreference.dark,
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {settings.themePreference},
                    onSelectionChanged: (selection) =>
                        repository.setThemePreference(selection.single),
                  ),
                ),
                const _SectionHeader('Units'),
                ListTile(
                  title: const Text('Weight and distance'),
                  subtitle: SegmentedButton<UnitSystem>(
                    segments: const [
                      ButtonSegment(
                        value: UnitSystem.metric,
                        label: Text('kg, km'),
                      ),
                      ButtonSegment(
                        value: UnitSystem.imperial,
                        label: Text('lb, mi'),
                      ),
                    ],
                    selected: {settings.unitSystem},
                    onSelectionChanged: (selection) =>
                        repository.setUnitSystem(selection.single),
                  ),
                ),
                ListTile(
                  title: const Text('Currency'),
                  subtitle: const Text('Used for gym subscriptions'),
                  trailing: DropdownButton<String>(
                    value: settings.currencyCode,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final code in _currencies)
                        DropdownMenuItem(value: code, child: Text(code)),
                    ],
                    onChanged: (code) => repository.setCurrencyCode(code!),
                  ),
                ),
                const _SectionHeader('Rest timer'),
                ListTile(
                  title: const Text('Rest between sets'),
                  subtitle: const Text('Starts when you tick a set done'),
                  trailing: DropdownButton<int>(
                    value: settings.restSeconds,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final seconds in {
                        ..._restLengths,
                        settings.restSeconds,
                      })
                        DropdownMenuItem(
                          value: seconds,
                          child: Text(
                            seconds == 0 ? 'Off' : formatDuration(seconds),
                          ),
                        ),
                    ],
                    onChanged: (seconds) => repository.setRestSeconds(seconds!),
                  ),
                ),
                const _SectionHeader('AI assistant'),
                const _AiTile(),
                const _SectionHeader('Data'),
                BackupTiles(lastBackupAt: settings.lastBackupAt),
                const _ErrorLogTile(),
              ],
            ),
    );
  }
}

class _AiTile extends ConsumerWidget {
  const _AiTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(aiSettingsProvider).value;
    return ListTile(
      leading: const Icon(Icons.auto_awesome_outlined),
      title: const Text('AI provider'),
      subtitle: Text(
        settings == null
            ? 'Off · add your API key to turn on AI features'
            : '${settings.provider.label} · ${settings.model} · '
                  'key ending ${settings.keyHint}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(Routes.aiSettings),
    );
  }
}

/// Only there once something went wrong, so it can be sent along.
class _ErrorLogTile extends ConsumerStatefulWidget {
  const _ErrorLogTile();

  @override
  ConsumerState<_ErrorLogTile> createState() => _ErrorLogTileState();
}

class _ErrorLogTileState extends ConsumerState<_ErrorLogTile> {
  @override
  Widget build(BuildContext context) {
    final log = ref.watch(errorLogProvider).value;
    if (log == null || !log.hasEntries) return const SizedBox.shrink();

    return ListTile(
      leading: const Icon(Icons.bug_report_outlined),
      title: const Text('Share error log'),
      subtitle: const Text('Errors djym recorded, to help find bugs'),
      trailing: IconButton(
        tooltip: 'Clear error log',
        icon: const Icon(Icons.delete_outline),
        onPressed: () => setState(log.clear),
      ),
      onTap: () => SharePlus.instance.share(
        ShareParams(
          files: [XFile(log.file.path, mimeType: 'text/plain')],
          subject: 'djym error log',
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
