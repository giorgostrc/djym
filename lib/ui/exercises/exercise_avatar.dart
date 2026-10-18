import 'package:djym/data/database/app_database.dart';
import 'package:djym/data/repositories/exercise_repository.dart';
import 'package:djym/ui/exercises/tracking_type_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExerciseAvatar extends ConsumerWidget {
  const ExerciseAvatar(this.exercise, {super.key});

  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallback = Icon(exercise.trackingType.icon);
    final image = ref.watch(exerciseThumbnailProvider(exercise.id)).value;
    if (image == null) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.memory(
        image,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
