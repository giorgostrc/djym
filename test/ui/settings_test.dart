import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loggym/app.dart';
import 'package:loggym/data/database/app_database.dart';
import 'package:loggym/data/database/database_provider.dart';
import 'package:loggym/ui/settings/backup_tiles.dart';
import 'package:loggym/ui/settings/settings_screen.dart';

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

  Finder field(String label) => find.widgetWithText(TextField, label);

  Future<Settings> settings() =>
      database.select(database.settingsTable).getSingle();

  testWidgets('a first name is saved and greets on the calendar', (
    tester,
  ) async {
    await openSettings(tester);

    await tester.enterText(field('First name'), 'Alex');
    await tester.pump();
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    expect((await settings()).firstName, 'Alex');
    expect(find.textContaining(', Alex'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('an invalid email is flagged on leaving and not saved', (
    tester,
  ) async {
    await openSettings(tester);

    await tester.enterText(field('Email'), 'alex@');
    await tester.tap(field('Last name'));
    await tester.pump();

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect((await settings()).email, isNull);

    await tester.enterText(field('Email'), 'alex@example.com');
    await tester.pump();

    expect(find.text('Enter a valid email address'), findsNothing);
    expect((await settings()).email, 'alex@example.com');

    await unmountApp(tester);
  });

  testWidgets('clearing a field removes the saved value', (tester) async {
    await openSettings(tester);

    await tester.enterText(field('Last name'), 'Smith');
    await tester.pump();
    await tester.enterText(field('Last name'), '');
    await tester.pump();

    expect((await settings()).lastName, isNull);

    await unmountApp(tester);
  });

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
