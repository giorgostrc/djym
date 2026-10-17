import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loggym/data/repositories/settings_repository.dart';
import 'package:loggym/domain/theme_preference.dart';
import 'package:loggym/domain/unit_system.dart';

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
              children: [
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
                ListTile(
                  title: const Text('Units'),
                  subtitle: SegmentedButton<UnitSystem>(
                    segments: const [
                      ButtonSegment(
                        value: UnitSystem.metric,
                        label: Text('Metric (kg)'),
                      ),
                      ButtonSegment(
                        value: UnitSystem.imperial,
                        label: Text('Imperial (lb)'),
                      ),
                    ],
                    selected: {settings.unitSystem},
                    onSelectionChanged: (selection) =>
                        repository.setUnitSystem(selection.single),
                  ),
                ),
              ],
            ),
    );
  }
}
