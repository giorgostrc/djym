import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loggym/data/repositories/workout_session_repository.dart';
import 'package:loggym/domain/unit_system.dart';
import 'package:loggym/ui/exercises/exercise_avatar.dart';
import 'package:loggym/ui/session/last_performance_sheet.dart';
import 'package:loggym/ui/session/set_description.dart';
import 'package:loggym/ui/session/set_row.dart';

class ExerciseCard extends ConsumerWidget {
  const ExerciseCard({
    required this.entry,
    required this.sessionId,
    required this.index,
    required this.units,
    super.key,
  });

  final SessionExercise entry;
  final int sessionId;
  final int index;
  final UnitSystem units;

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(workoutSessionRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    await repository.deleteSets(entry.sets);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          persist: false,
          content: Text('${entry.exercise.title} removed'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => repository.restoreSets(entry.sets),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercise = entry.exercise;
    final records = ref
        .watch(exerciseRecordsProvider((exercise, sessionId)))
        .value;
    final best = records?.allTimeBest;
    final last = records?.lastPerformance;

    return Card.outlined(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.only(left: 16, right: 4),
            leading: ExerciseAvatar(exercise),
            title: Text(
              exercise.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: best == null
                ? null
                : Text(
                    'Best: ${describeSet(best, exercise.trackingType, units)}',
                  ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopupMenuButton<void>(
                  tooltip: 'Exercise options',
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      onTap: () => _remove(context, ref),
                      child: const Text('Remove from workout'),
                    ),
                  ],
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.drag_handle, semanticLabel: 'Reorder'),
                  ),
                ),
              ],
            ),
          ),
          if (last != null)
            _LastPerformanceRow(
              summary: [
                for (final set in last.sets)
                  describeSet(set, exercise.trackingType, units),
              ].join(', '),
              date: MaterialLocalizations.of(
                context,
              ).formatShortMonthDay(last.date),
              hasComments: last.sets.any((set) => set.comment != null),
              onTap: () => showLastPerformance(
                context,
                exercise: exercise,
                last: last,
                units: units,
              ),
            ),
          for (final (setIndex, set) in entry.sets.indexed)
            SetRow(
              key: ValueKey(set.id),
              set: set,
              number: setIndex + 1,
              trackingType: exercise.trackingType,
              units: units,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: TextButton.icon(
              onPressed: () => ref
                  .read(workoutSessionRepositoryProvider)
                  .addSet(sessionId, exercise.id),
              icon: const Icon(Icons.add),
              label: const Text('Add set'),
            ),
          ),
        ],
      ),
    );
  }
}

/// A one-line glance at the previous session; the full list opens on tap.
class _LastPerformanceRow extends StatelessWidget {
  const _LastPerformanceRow({
    required this.summary,
    required this.date,
    required this.hasComments,
    required this.onTap,
  });

  final String summary;
  final String date;
  final bool hasComments;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quiet = theme.colorScheme.onSurfaceVariant;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              spacing: 8,
              children: [
                Icon(Icons.history, size: 18, color: quiet),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Last · $date  ',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: summary),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: quiet),
                  ),
                ),
                if (hasComments)
                  Icon(
                    Icons.mode_comment_outlined,
                    size: 16,
                    color: quiet,
                    semanticLabel: 'Has comments',
                  ),
                Icon(Icons.chevron_right, size: 20, color: quiet),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
