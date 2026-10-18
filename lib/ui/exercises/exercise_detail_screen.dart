import 'package:djym/data/repositories/exercise_history_repository.dart';
import 'package:djym/data/repositories/exercise_repository.dart';
import 'package:djym/data/repositories/settings_repository.dart';
import 'package:djym/domain/tracking_type.dart';
import 'package:djym/domain/unit_system.dart';
import 'package:djym/routing/routes.dart';
import 'package:djym/ui/core/placeholder_body.dart';
import 'package:djym/ui/core/stat_tile.dart';
import 'package:djym/ui/exercises/progress_chart.dart';
import 'package:djym/ui/exercises/remove_exercise.dart';
import 'package:djym/ui/exercises/tracking_type_display.dart';
import 'package:djym/ui/session/set_description.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// An exercise's best set, progress over time and every workout it was in.
class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({required this.exerciseId, super.key});

  final int exerciseId;

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ExerciseWithMuscles entry,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    context.pop();
    await removeExerciseWithUndo(
      messenger: messenger,
      repository: ref.read(exerciseRepositoryProvider),
      entry: entry,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref
        .watch(exercisesProvider)
        .value
        ?.where((entry) => entry.exercise.id == exerciseId)
        .firstOrNull;
    final history = ref.watch(exerciseHistoryProvider(exerciseId)).value;
    final units =
        ref.watch(settingsProvider).value?.unitSystem ?? UnitSystem.metric;
    if (entry == null || history == null) return const Scaffold();

    final exercise = entry.exercise;
    final guidance = exercise.formGuidance?.trim() ?? '';
    void openWorkout(ExerciseWorkout workout) => context.push(
      Routes.exerciseWorkout(exerciseId, workout.session.id),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(exercise.title),
        actions: [
          IconButton(
            tooltip: 'Edit exercise',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(Routes.exerciseEdit(exerciseId)),
          ),
          PopupMenuButton<void>(
            tooltip: 'Exercise options',
            itemBuilder: (_) => [
              PopupMenuItem(
                onTap: () => _delete(context, ref, entry),
                child: const Text('Delete exercise'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          _Header(entry),
          if (history.bestWorkout case final best?) ...[
            _BestSetCard(
              workout: best,
              trackingType: exercise.trackingType,
              units: units,
              onTap: () => openWorkout(best),
            ),
            const SizedBox(height: 8),
            _Stats(history: history, units: units),
            _ProgressSection(history: history, units: units),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: PlaceholderBody(
                icon: Icons.insights,
                message:
                    'Your best set and progress show up here\n'
                    'after your first workout',
              ),
            ),
          if (guidance.isNotEmpty) ...[
            const _SectionTitle('Form cues'),
            Text(guidance),
          ],
          if (history.workouts.isNotEmpty) ...[
            _SectionTitle('History · ${history.workouts.length}'),
            for (final workout in history.workouts)
              _WorkoutTile(
                workout: workout,
                trackingType: exercise.trackingType,
                units: units,
                isRecord: history.recordSessionIds.contains(workout.session.id),
                onTap: () => openWorkout(workout),
              ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _Header extends ConsumerWidget {
  const _Header(this.entry);

  final ExerciseWithMuscles entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final exercise = entry.exercise;
    final image = ref.watch(exerciseThumbnailProvider(exercise.id)).value;
    final muscles = entry.muscles.map((muscle) => muscle.name).join(', ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        spacing: 16,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox.square(
              dimension: 72,
              child: image == null
                  ? ColoredBox(
                      color: colors.secondaryContainer,
                      child: Icon(
                        exercise.trackingType.icon,
                        size: 32,
                        color: colors.onSecondaryContainer,
                      ),
                    )
                  : Image.memory(image, fit: BoxFit.cover),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                if (muscles.isNotEmpty)
                  Text(muscles, style: theme.textTheme.titleSmall),
                Text(
                  exercise.trackingType.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BestSetCard extends StatelessWidget {
  const _BestSetCard({
    required this.workout,
    required this.trackingType,
    required this.units,
    required this.onTap,
  });

  final ExerciseWorkout workout;
  final TrackingType trackingType;
  final UnitSystem units;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(workout.session.startedAt);

    return Card.filled(
      margin: const EdgeInsets.only(top: 8),
      color: colors.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      spacing: 6,
                      children: [
                        Icon(
                          Icons.emoji_events,
                          size: 18,
                          color: colors.onPrimaryContainer,
                        ),
                        Text(
                          'Personal best',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      describeSet(workout.best, trackingType, units),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      date,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.history, required this.units});

  final ExerciseHistory history;
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    final workouts = history.workouts;
    final oneRepMax = history.trackingType == TrackingType.weightReps
        ? ProgressMetric.estimatedOneRepMax.bestIn(
            workouts.expand((workout) => workout.sets),
          )
        : null;
    final tiles = [
      if (oneRepMax != null)
        (
          value: ProgressMetric.estimatedOneRepMax.format(oneRepMax, units),
          label: 'Est. 1RM',
        )
      else
        (
          value: '${workouts.fold(0, (sum, w) => sum + w.sets.length)}',
          label: 'Sets',
        ),
      (value: '${workouts.length}', label: 'Workouts'),
      (
        value: DateFormat.MMMd().format(workouts.first.session.startedAt),
        label: 'Last done',
      ),
    ];

    return Row(
      spacing: 8,
      children: [
        for (final (:value, :label) in tiles)
          Expanded(
            child: StatTile(value: value, label: label),
          ),
      ],
    );
  }
}

class _ProgressSection extends StatefulWidget {
  const _ProgressSection({required this.history, required this.units});

  final ExerciseHistory history;
  final UnitSystem units;

  @override
  State<_ProgressSection> createState() => _ProgressSectionState();
}

class _ProgressSectionState extends State<_ProgressSection> {
  late ProgressMetric _metric = ProgressMetric.forType(
    widget.history.trackingType,
  ).first;
  ProgressRange _range = ProgressRange.all;

  @override
  Widget build(BuildContext context) {
    final metrics = ProgressMetric.forType(widget.history.trackingType);
    final points = progressPoints(
      widget.history,
      _metric,
      _range,
      now: DateTime.now(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(metrics.length == 1 ? _metric.label : 'Progress'),
        if (metrics.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Wrap(
              spacing: 8,
              children: [
                for (final metric in metrics)
                  ChoiceChip(
                    label: Text(metric.label),
                    selected: metric == _metric,
                    onSelected: (_) => setState(() => _metric = metric),
                  ),
              ],
            ),
          ),
        ProgressChart(
          points: points,
          metric: _metric,
          units: widget.units,
          emptyMessage: widget.history.workouts.length < 2
              ? 'Your trend appears after your next workout'
              : 'No workouts in this period',
        ),
        const SizedBox(height: 12),
        SegmentedButton<ProgressRange>(
          showSelectedIcon: false,
          segments: [
            for (final range in ProgressRange.values)
              ButtonSegment(value: range, label: Text(range.label)),
          ],
          selected: {_range},
          onSelectionChanged: (selected) =>
              setState(() => _range = selected.single),
        ),
      ],
    );
  }
}

class _WorkoutTile extends StatelessWidget {
  const _WorkoutTile({
    required this.workout,
    required this.trackingType,
    required this.units,
    required this.isRecord,
    required this.onTap,
  });

  final ExerciseWorkout workout;
  final TrackingType trackingType;
  final UnitSystem units;
  final bool isRecord;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        MaterialLocalizations.of(
          context,
        ).formatMediumDate(workout.session.startedAt),
      ),
      subtitle: Text(
        [
          for (final set in workout.sets) describeSet(set, trackingType, units),
        ].join('  ·  '),
      ),
      trailing: isRecord
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colors.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'PR',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onTertiaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
      onTap: onTap,
    );
  }
}
