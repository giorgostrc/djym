import 'package:djym/data/database/app_database.dart';
import 'package:djym/data/repositories/settings_repository.dart';
import 'package:djym/domain/theme_preference.dart';
import 'package:djym/domain/unit_system.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late SettingsRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = SettingsRepository(database);
  });

  tearDown(() => database.close());

  test('seeds default settings on database creation', () async {
    final settings = await repository.watchSettings().first;

    expect(settings.themePreference, ThemePreference.system);
    expect(settings.unitSystem, UnitSystem.metric);
  });

  test('persists theme and unit changes', () async {
    await repository.setThemePreference(ThemePreference.dark);
    await repository.setUnitSystem(UnitSystem.imperial);

    final settings = await repository.watchSettings().first;

    expect(settings.themePreference, ThemePreference.dark);
    expect(settings.unitSystem, UnitSystem.imperial);
  });
}
