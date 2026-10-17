import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loggym/data/database/app_database.dart';
import 'package:loggym/data/database/database_provider.dart';
import 'package:loggym/domain/theme_preference.dart';
import 'package:loggym/domain/unit_system.dart';

class SettingsRepository {
  const SettingsRepository(this._database);

  final AppDatabase _database;

  Stream<Settings> watchSettings() =>
      _database.select(_database.settingsTable).watchSingle();

  Future<void> setThemePreference(ThemePreference preference) => _write(
    SettingsTableCompanion(themePreference: Value(preference)),
  );

  Future<void> setUnitSystem(UnitSystem unitSystem) =>
      _write(SettingsTableCompanion(unitSystem: Value(unitSystem)));

  Future<void> _write(SettingsTableCompanion changes) =>
      _database.update(_database.settingsTable).write(changes);
}

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(appDatabaseProvider)),
);

final settingsProvider = StreamProvider<Settings>(
  (ref) => ref.watch(settingsRepositoryProvider).watchSettings(),
);
