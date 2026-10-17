import 'package:flutter/material.dart';
import 'package:loggym/data/repositories/exercise_repository.dart';

Future<void> removeExerciseWithUndo({
  required ScaffoldMessengerState messenger,
  required ExerciseRepository repository,
  required ExerciseWithMuscles entry,
}) async {
  final title = entry.exercise.title;
  final thumbnail = await repository.thumbnail(entry.exercise.id);
  final removal = await repository.removeExercise(entry.exercise.id);

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        persist: false,
        content: Text(switch (removal) {
          ExerciseRemoval.deleted => '$title deleted',
          ExerciseRemoval.archived => '$title archived, its history is kept',
        }),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () =>
              repository.restoreExercise(entry, thumbnail: thumbnail),
        ),
      ),
    );
}
