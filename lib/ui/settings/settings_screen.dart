import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loggym/data/repositories/settings_repository.dart';
import 'package:loggym/domain/theme_preference.dart';
import 'package:loggym/domain/unit_system.dart';
import 'package:loggym/ui/settings/backup_tiles.dart';
import 'package:loggym/ui/settings/profile_field.dart';

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

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

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
                const _SectionHeader('Profile'),
                ProfileField(
                  label: 'First name',
                  initialValue: settings.firstName,
                  onSave: repository.setFirstName,
                ),
                ProfileField(
                  label: 'Last name',
                  initialValue: settings.lastName,
                  onSave: repository.setLastName,
                ),
                ProfileField(
                  label: 'Email',
                  initialValue: settings.email,
                  keyboardType: TextInputType.emailAddress,
                  textCapitalization: TextCapitalization.none,
                  validate: (email) =>
                      email.isEmpty || _emailPattern.hasMatch(email)
                      ? null
                      : 'Enter a valid email address',
                  onSave: repository.setEmail,
                ),
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
                const _SectionHeader('Data'),
                BackupTiles(lastBackupAt: settings.lastBackupAt),
              ],
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
