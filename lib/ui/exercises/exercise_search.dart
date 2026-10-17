import 'package:loggym/data/repositories/exercise_repository.dart';

extension ExerciseSearch on List<ExerciseWithMuscles> {
  List<ExerciseWithMuscles> matching(String query, {int? muscleId}) {
    final needle = query.trim().toLowerCase();
    return [
      for (final entry in this)
        if (entry.exercise.title.toLowerCase().contains(needle) &&
            (muscleId == null ||
                entry.muscles.any((muscle) => muscle.id == muscleId)))
          entry,
    ];
  }
}
