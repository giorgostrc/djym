import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loggym/app.dart';
import 'package:loggym/data/database/app_database.dart';
import 'package:loggym/data/database/database_provider.dart';
import 'package:loggym/data/repositories/exercise_repository.dart';
import 'package:loggym/data/services/wger_client.dart';
import 'package:loggym/domain/tracking_type.dart';
import 'package:loggym/ui/exercises/exercise_form_screen.dart';

class _FakeImagePicker implements ImagePicker {
  ImageSource? requestedSource;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    requestedSource = source;
    return XFile.fromData(Uint8List.fromList([7, 7, 7]));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final fixture = File(
    'test/fixtures/wger_search_bench_press.json',
  ).readAsBytesSync();
  late AppDatabase database;
  late _FakeImagePicker picker;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    picker = _FakeImagePicker();
  });

  tearDown(() => database.close());

  Future<void> openExercisesTab(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          imagePickerProvider.overrideWithValue(picker),
          wgerClientProvider.overrideWithValue(
            WgerClient(
              MockClient(
                (request) async => request.url.path == '/api/v2/exerciseinfo/'
                    ? http.Response.bytes(fixture, 200)
                    : http.Response.bytes([1, 2, 3], 200),
              ),
            ),
          ),
        ],
        child: const LogGymApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exercises'));
    await tester.pumpAndSettle();
  }

  Future<void> choosePhotoOption(WidgetTester tester, String option) async {
    await tester.tap(find.byTooltip('Change photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(option));
    await tester.pumpAndSettle();
  }

  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('replaces a prefilled wger photo with one from the camera', (
    tester,
  ) async {
    await openExercisesTab(tester);
    await tester.tap(find.text('Create your first exercise'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'bench');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();

    await choosePhotoOption(tester, 'Take photo');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await database.select(database.exercises).getSingle();
    expect(picker.requestedSource, ImageSource.camera);
    expect(saved.externalId, startsWith('wger:'));
    expect(await ExerciseRepository(database).thumbnail(saved.id), [7, 7, 7]);

    await unmountApp(tester);
  });

  testWidgets('removes the photo of an existing exercise', (
    tester,
  ) async {
    await ExerciseRepository(database).saveExercise(
      title: 'Dips',
      trackingType: TrackingType.reps,
      muscleIds: const [],
      thumbnail: Uint8List.fromList([1, 2, 3]),
    );
    await openExercisesTab(tester);
    await tester.tap(find.text('Dips'));
    await tester.pumpAndSettle();

    await choosePhotoOption(tester, 'Remove photo');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await database.select(database.exercises).getSingle();
    expect(await ExerciseRepository(database).thumbnail(saved.id), isNull);

    await unmountApp(tester);
  });

  testWidgets('a new exercise without a photo offers no remove option', (
    tester,
  ) async {
    await openExercisesTab(tester);
    await tester.tap(find.text('Create your first exercise'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Change photo'));
    await tester.pumpAndSettle();

    expect(find.text('Choose from gallery'), findsOneWidget);
    expect(find.text('Remove photo'), findsNothing);

    await unmountApp(tester);
  });
}
