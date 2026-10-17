import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loggym/data/database/app_database.dart';
import 'package:loggym/data/services/thumbnail_store.dart';
import 'package:loggym/ui/exercises/tracking_type_display.dart';

class ExerciseAvatar extends ConsumerWidget {
  const ExerciseAvatar(this.exercise, {super.key});

  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallback = Icon(exercise.trackingType.icon);
    final path = exercise.thumbnailPath;
    if (path == null) return fallback;

    final store = ref.watch(thumbnailStoreProvider).value;
    if (store == null) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        store.file(path),
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
