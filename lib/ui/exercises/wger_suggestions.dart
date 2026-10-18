import 'package:djym/data/repositories/exercise_repository.dart';
import 'package:djym/data/services/wger_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const minimumSuggestionTermLength = 3;

/// Fits four and a half rows, so a cut-off row hints that the list scrolls.
const _panelMaxHeight = 324.0;

class WgerSuggestions extends ConsumerWidget {
  const WgerSuggestions({
    required this.term,
    required this.onSelected,
    super.key,
  });

  final String term;
  final ValueChanged<WgerExercise> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (term.length < minimumSuggestionTermLength) {
      return const SizedBox.shrink();
    }

    final textTheme = Theme.of(context).textTheme;
    final quiet = TextStyle(color: Theme.of(context).colorScheme.outline);
    final inLibrary = {
      for (final entry
          in ref.watch(exercisesProvider).value ?? <ExerciseWithMuscles>[])
        entry.exercise.externalId,
    };

    return switch (ref.watch(wgerSearchProvider(term))) {
      AsyncData(value: []) => const SizedBox.shrink(),
      AsyncData(:final value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              'Suggestions from wger · ${value.length}',
              style: textTheme.labelMedium,
            ),
          ),
          Card.outlined(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _panelMaxHeight),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: value.length,
                itemBuilder: (context, index) => _SuggestionTile(
                  suggestion: value[index],
                  inLibrary: inLibrary.contains(value[index].externalId),
                  onTap: () => onSelected(value[index]),
                ),
              ),
            ),
          ),
        ],
      ),
      AsyncError() => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'wger suggestions are unavailable right now',
          style: textTheme.bodySmall?.merge(quiet),
        ),
      ),
      _ => const Padding(
        padding: EdgeInsets.only(top: 8),
        child: LinearProgressIndicator(minHeight: 2),
      ),
    };
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.suggestion,
    required this.inLibrary,
    required this.onTap,
  });

  final WgerExercise suggestion;
  final bool inLibrary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: !inLibrary,
      leading: WgerThumbnail(suggestion.thumbnailUrl),
      title: Text(suggestion.name),
      subtitle: suggestion.muscleNames.isEmpty
          ? null
          : Text(suggestion.muscleNames.join(', ')),
      trailing: inLibrary ? const Text('In library') : null,
      onTap: onTap,
    );
  }
}

/// Shows where the form's values came from, with a way to undo it.
class PrefillCard extends StatelessWidget {
  const PrefillCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onClear,
    super.key,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card.filled(
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        leading: leading,
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: TextButton(onPressed: onClear, child: const Text('Clear')),
      ),
    );
  }
}

class WgerThumbnail extends StatelessWidget {
  const WgerThumbnail(this.url, {super.key});

  final String? url;

  @override
  Widget build(BuildContext context) {
    const placeholder = Icon(Icons.fitness_center);
    final url = this.url;

    return SizedBox.square(
      dimension: 40,
      child: url == null
          ? placeholder
          : ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
              ),
            ),
    );
  }
}
