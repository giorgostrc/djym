import 'package:djym/data/database/app_database.dart';
import 'package:djym/data/database/database_provider.dart';
import 'package:djym/domain/theme_preference.dart';
import 'package:djym/domain/unit_system.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<void> setCurrencyCode(String currencyCode) =>
      _write(SettingsTableCompanion(currencyCode: Value(currencyCode)));

  Future<void> setRestSeconds(int seconds) =>
      _write(SettingsTableCompanion(restSeconds: Value(seconds)));

  Future<void> markRestAlertsPrompted() =>
      _write(const SettingsTableCompanion(restAlertsPrompted: Value(true)));

  Future<void> markBackedUp(DateTime at) =>
      _write(SettingsTableCompanion(lastBackupAt: Value(at)));

  Future<void> _write(SettingsTableCompanion changes) =>
      _database.update(_database.settingsTable).write(changes);
}

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(appDatabaseProvider)),
);

final settingsProvider = StreamProvider<Settings>(
  (ref) => ref.watch(settingsRepositoryProvider).watchSettings(),
);
