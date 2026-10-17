import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loggym/data/database/app_database.dart';
import 'package:loggym/data/repositories/settings_repository.dart';
import 'package:loggym/domain/theme_preference.dart';
import 'package:loggym/domain/unit_system.dart';

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
