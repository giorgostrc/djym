import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loggym/data/repositories/exercise_repository.dart';
import 'package:loggym/routing/routes.dart';
import 'package:loggym/ui/core/text_input.dart';
import 'package:loggym/ui/exercises/exercise_avatar.dart';
import 'package:loggym/ui/exercises/exercise_search.dart';

/// Returns the picked exercise ids in the order they were selected.
Future<List<int>?> showExercisePicker(BuildContext context) =>
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const ExercisePicker(),
      ),
    );

class ExercisePicker extends ConsumerStatefulWidget {
  const ExercisePicker({super.key});

  @override
  ConsumerState<ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends ConsumerState<ExercisePicker> {
  final _selectedIds = <int>[];
  final _search = TextEditingController();

  String get _query => _search.text;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _onQueryChanged(String _) => setState(() {});

  Future<void> _createExercise() async {
    final title = _query.trim();
    final id = await context.push<int>(
      Uri(
        path: Routes.newExercise,
        queryParameters: title.isEmpty ? null : {'title': title},
      ).toString(),
    );
    if (id != null) setState(() => _selectedIds.add(id));
  }

  void _toggle(int id) => setState(
    () => _selectedIds.contains(id)
        ? _selectedIds.remove(id)
        : _selectedIds.add(id),
  );

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(exercisesProvider).value ?? const [];
    final matches = exercises.matching(_query);
    final hasExactMatch = matches.any(
      (entry) =>
          entry.exercise.title.toLowerCase() == _query.trim().toLowerCase(),
    );

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _search,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search exercises',
            border: InputBorder.none,
            suffixIcon: clearButton(_search, onChanged: _onQueryChanged),
          ),
          onChanged: _onQueryChanged,
        ),
      ),
      body: ListView(
        children: [
          if (!hasExactMatch)
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(
                _query.trim().isEmpty
                    ? 'Create exercise'
                    : 'Create "${_query.trim()}"',
              ),
              onTap: _createExercise,
            ),
          for (final entry in matches)
            CheckboxListTile(
              value: _selectedIds.contains(entry.exercise.id),
              onChanged: (_) => _toggle(entry.exercise.id),
              secondary: ExerciseAvatar(entry.exercise),
              title: Text(entry.exercise.title),
              subtitle: entry.muscles.isEmpty
                  ? null
                  : Text(entry.muscles.map((muscle) => muscle.name).join(', ')),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _selectedIds.isEmpty
                ? null
                : () => Navigator.pop(context, _selectedIds),
            child: Text(
              _selectedIds.isEmpty
                  ? 'Select exercises'
                  : 'Add ${_selectedIds.length}',
            ),
          ),
        ),
      ),
    );
  }
}
