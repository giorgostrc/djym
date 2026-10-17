import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loggym/data/repositories/exercise_repository.dart';
import 'package:loggym/routing/routes.dart';
import 'package:loggym/ui/core/placeholder_body.dart';
import 'package:loggym/ui/exercises/exercise_search.dart';
import 'package:loggym/ui/exercises/remove_exercise.dart';
import 'package:loggym/ui/exercises/tracking_type_display.dart';

class ExercisesScreen extends ConsumerWidget {
  const ExercisesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercises = ref.watch(exercisesProvider).value;
    void createExercise() => context.push(Routes.newExercise);

    return Scaffold(
      appBar: AppBar(title: const Text('Exercises')),
      floatingActionButton: exercises?.isEmpty ?? true
          ? null
          : FloatingActionButton.extended(
              onPressed: createExercise,
              icon: const Icon(Icons.add),
              label: const Text('Add exercise'),
            ),
      body: switch (exercises) {
        null => const Center(child: CircularProgressIndicator()),
        [] => PlaceholderBody(
          icon: Icons.fitness_center,
          message: 'No exercises yet',
          action: FilledButton.icon(
            onPressed: createExercise,
            icon: const Icon(Icons.add),
            label: const Text('Create your first exercise'),
          ),
        ),
        _ => _SearchableExerciseList(exercises: exercises),
      },
    );
  }
}

class _SearchableExerciseList extends ConsumerStatefulWidget {
  const _SearchableExerciseList({required this.exercises});

  final List<ExerciseWithMuscles> exercises;

  @override
  ConsumerState<_SearchableExerciseList> createState() =>
      _SearchableExerciseListState();
}

class _SearchableExerciseListState
    extends ConsumerState<_SearchableExerciseList> {
  final _search = TextEditingController();
  int? _muscleId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final muscles = ref.watch(musclesProvider).value ?? const [];
    final matches = widget.exercises.matching(
      _search.text,
      muscleId: _muscleId,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SearchBar(
            controller: _search,
            hintText: 'Search exercises',
            leading: const Icon(Icons.search),
            trailing: [
              if (_search.text.isNotEmpty)
                IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(_search.clear),
                ),
            ],
            onChanged: (_) => setState(() {}),
          ),
        ),
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              for (final muscle in muscles)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(muscle.name),
                    selected: muscle.id == _muscleId,
                    onSelected: (selected) =>
                        setState(() => _muscleId = selected ? muscle.id : null),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: matches.isEmpty
              ? const PlaceholderBody(
                  icon: Icons.search_off,
                  message: 'No exercises match',
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: matches.length,
                  itemBuilder: (context, index) =>
                      _ExerciseTile(entry: matches[index]),
                ),
        ),
      ],
    );
  }
}

class _ExerciseTile extends ConsumerWidget {
  const _ExerciseTile({required this.entry});

  final ExerciseWithMuscles entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercise = entry.exercise;
    final colors = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey(exercise.id),
      direction: DismissDirection.endToStart,
      background: ColoredBox(
        color: colors.errorContainer,
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 24),
            child: Icon(Icons.delete_outline, color: colors.onErrorContainer),
          ),
        ),
      ),
      confirmDismiss: (_) async {
        await removeExerciseWithUndo(
          messenger: ScaffoldMessenger.of(context),
          repository: ref.read(exerciseRepositoryProvider),
          entry: entry,
        );
        return true;
      },
      child: ListTile(
        leading: Icon(exercise.trackingType.icon),
        title: Text(exercise.title),
        subtitle: entry.muscles.isEmpty
            ? null
            : Text(entry.muscles.map((muscle) => muscle.name).join(', ')),
        onTap: () => context.push(Routes.exercise(exercise.id)),
      ),
    );
  }
}
