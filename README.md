# djym

Local-first gym session logger for Android and iOS.

## Stack

| Concern | Choice |
|---|---|
| UI | Flutter (Material 3) |
| State | Riverpod 3 (manual providers, no codegen) |
| Navigation | go_router (`StatefulShellRoute` for the bottom tabs) |
| Persistence | Drift on SQLite |
| Calendar | table_calendar |
| Lints | very_good_analysis |

## Setup

Requires Flutter 3.38.5 (stable) and, on Linux hosts, `libsqlite3-dev` for running tests.

```bash
flutter pub get
dart run build_runner build --force-jit
flutter run
```

`--force-jit` is needed because `sqlite3` uses native build hooks, which the default AOT build script compilation does not support.

## Development

```bash
dart run build_runner watch --force-jit   # regenerate *.g.dart on save
dart format lib test
flutter analyze
flutter test
```

## Project structure

Follows the [Flutter app architecture guide](https://docs.flutter.dev/app-architecture): a data layer exposing repositories and a UI layer consuming them through Riverpod providers.

```
lib/
  data/
    database/       Drift tables, database class, database provider
    repositories/   Data access exposed to the UI as providers
  domain/           Pure Dart types and business logic
  routing/          Route paths and the GoRouter configuration
  ui/
    core/           Theme, app shell, shared widgets
    <feature>/      One folder per screen
drift_schemas/      Committed schema snapshots, one per schema version
```

`lib/data/database/` and `lib/domain/` must not import Flutter: Drift runs the database file in a plain Dart isolate when exporting schemas.

## Schema migrations

Drift's `make-migrations` workflow keeps a JSON snapshot per schema version and generates typed migration steps and tests.

The schema was reset to v1 before the first real install, so there are no earlier versions to migrate from yet.

1. Change the tables in `lib/data/database/tables.dart`.
2. Bump `schemaVersion` in `lib/data/database/app_database.dart`.
3. Run `dart run drift_dev make-migrations`.
4. Implement the generated `fromXToY` step in `onUpgrade: stepByStep(...)`.
5. Run `flutter test test/drift` to verify the migration against the snapshots.

Commit `drift_schemas/`, `*.steps.dart` and `test/drift/`; only `*.g.dart` is ignored.

## Conventions

- Weights are stored in kilograms and converted for display.
- Money is stored as integer cents.
- A single `settings` row is seeded on database creation, so the backup file also carries user preferences.
- Exercise photos are stored as JPEG/PNG blobs in `exercise_thumbnails` (one row per exercise, user photos capped at 256 px), so a backup is the single database file.

## Brand

djym (djinn + gym) uses five colours, mapped to Material roles in `lib/ui/core/app_theme.dart`:
deep teal `#1A535C`, turquoise `#4ECDC4`, mint `#F7FFF7`, coral `#FF6B6B`, sunshine `#FFE66D`.
The dark theme sits on two neutral grey-blue shades: ink `#141E24` (background) and slate `#22313A` (cards).
Headings and the wordmark use Fredoka (SIL OFL, `assets/fonts/`); body text keeps the platform font.
Launcher icons and the in-app logo come from `tool/brand/djym-icon.jpg` via `tool/brand/make_icons.py`.
