import 'package:djym/app.dart';
import 'package:djym/data/database/app_database.dart';
import 'package:djym/data/database/database_provider.dart';
import 'package:djym/ui/settings/backup_tiles.dart';
import 'package:djym/ui/settings/settings_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));

  tearDown(() => database.close());

  Future<void> openSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const DjymApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
  }

  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Future<Settings> settings() =>
      database.select(database.settingsTable).getSingle();

  testWidgets('the currency is chosen from a list', (tester) async {
    await openSettings(tester);

    await tester.scrollUntilVisible(
      find.text('EUR'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('EUR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GBP').last);
    await tester.pumpAndSettle();

    expect((await settings()).currencyCode, 'GBP');

    await unmountApp(tester);
  });

  testWidgets('the rest length starts at 3 minutes and can be changed', (
    tester,
  ) async {
    await openSettings(tester);

    await tester.scrollUntilVisible(
      find.text('3:00'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('3:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1:30').last);
    await tester.pumpAndSettle();

    expect((await settings()).restSeconds, 90);

    await unmountApp(tester);
  });

  test('describes how long ago the last backup was', () {
    final now = DateTime(2026, 10, 18, 9);

    expect(describeLastBackup(null, now), 'Never backed up');
    expect(
      describeLastBackup(DateTime(2026, 10, 18, 1), now),
      'Last backup: today',
    );
    expect(
      describeLastBackup(DateTime(2026, 10, 17, 23), now),
      'Last backup: yesterday',
    );
    expect(
      describeLastBackup(DateTime(2026, 10, 6), now),
      'Last backup: 12 days ago',
    );
  });
}
