import 'package:djym/data/database/app_database.dart';
import 'package:djym/data/repositories/workout_session_repository.dart';
import 'package:djym/domain/unit_system.dart';
import 'package:djym/ui/exercises/exercise_avatar.dart';
import 'package:djym/ui/session/last_performance_sheet.dart';
import 'package:djym/ui/session/set_description.dart';
import 'package:djym/ui/session/set_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExerciseCard extends ConsumerWidget {
  const ExerciseCard({
    required this.entry,
    required this.sessionId,
    required this.index,
    required this.units,
    required this.expanded,
    required this.onToggleExpanded,
    super.key,
  });

  final SessionExercise entry;
  final int sessionId;
  final int index;
  final UnitSystem units;
  final bool expanded;
  final VoidCallback onToggleExpanded;

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
    final type = exercise.trackingType;
    final theme = Theme.of(context);
    final completed =
        entry.sets.isNotEmpty &&
        entry.sets.every((set) => set.completedAt != null);
    final animationDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Durations.medium2;

    return Card.outlined(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      clipBehavior: Clip.antiAlias,
      shape: completed
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.primary),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            expanded: expanded,
            child: ListTile(
              onTap: onToggleExpanded,
              contentPadding: const EdgeInsets.only(left: 16, right: 4),
              leading: Badge(
                isLabelVisible: completed,
                backgroundColor: theme.colorScheme.primary,
                offset: const Offset(4, -4),
                label: Icon(
                  Icons.check,
                  size: 12,
                  color: theme.colorScheme.onPrimary,
                ),
                child: ExerciseAvatar(exercise),
              ),
              title: Text(
                exercise.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
              subtitle: expanded && best != null
                  ? Text('Best: ${describeSet(best, type, units)}')
                  : _SetProgress(entry.sets, completed: completed),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: animationDuration,
                    curve: Easing.standard,
                    child: Icon(
                      Icons.expand_more,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
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
          ),
          AnimatedSize(
            duration: animationDuration,
            curve: Easing.standard,
            alignment: Alignment.topCenter,
            child: expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (last != null)
                        _LastPerformanceRow(
                          summary: [
                            for (final set in last.sets)
                              describeSet(set, exercise.trackingType, units),
                          ].join(', '),
                          date: MaterialLocalizations.of(
                            context,
                          ).formatShortMonthDay(last.date),
                          hasComments: last.sets.any(
                            (set) => set.comment != null,
                          ),
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
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// How far through its sets an exercise is, readable at a glance.
class _SetProgress extends StatelessWidget {
  const _SetProgress(this.sets, {required this.completed});

  final List<ExerciseSet> sets;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = sets.length;
    final done = sets.where((set) => set.completedAt != null).length;
    final setCount = '$total ${total == 1 ? 'set' : 'sets'}';

    if (completed) {
      return Text.rich(
        TextSpan(
          children: [
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.check_circle, size: 16),
              ),
            ),
            TextSpan(text: 'Completed · $setCount'),
          ],
        ),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    if (done == 0) return Text(setCount);
    return Text('$done of $setCount done');
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
