import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loggym/data/database/app_database.dart';
import 'package:loggym/data/repositories/exercise_repository.dart';
import 'package:loggym/domain/tracking_type.dart';
import 'package:loggym/ui/exercises/remove_exercise.dart';
import 'package:loggym/ui/exercises/tracking_type_display.dart';

class ExerciseFormScreen extends ConsumerWidget {
  const ExerciseFormScreen({this.exerciseId, this.initialTitle, super.key});

  final int? exerciseId;
  final String? initialTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (exerciseId == null) return _ExerciseForm(initialTitle: initialTitle);

    final existing = ref
        .watch(exercisesProvider)
        .value
        ?.where((entry) => entry.exercise.id == exerciseId)
        .firstOrNull;
    if (existing == null) return const Scaffold();

    return _ExerciseForm(existing: existing);
  }
}

class _ExerciseForm extends ConsumerStatefulWidget {
  const _ExerciseForm({this.existing, this.initialTitle});

  final ExerciseWithMuscles? existing;
  final String? initialTitle;

  @override
  ConsumerState<_ExerciseForm> createState() => _ExerciseFormState();
}

class _ExerciseFormState extends ConsumerState<_ExerciseForm> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(
    text: widget.existing?.exercise.title ?? widget.initialTitle,
  );
  late final _formGuidance = TextEditingController(
    text: widget.existing?.exercise.formGuidance,
  );
  late TrackingType _trackingType =
      widget.existing?.exercise.trackingType ?? TrackingType.weightReps;
  late final List<int> _muscleIds = [
    for (final muscle in widget.existing?.muscles ?? <Muscle>[]) muscle.id,
  ];
  var _dirty = false;

  @override
  void dispose() {
    _title.dispose();
    _formGuidance.dispose();
    super.dispose();
  }

  void _markDirty() => setState(() => _dirty = true);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final guidance = _formGuidance.text.trim();
    final id = await ref
        .read(exerciseRepositoryProvider)
        .saveExercise(
          id: widget.existing?.exercise.id,
          title: _title.text.trim(),
          trackingType: _trackingType,
          formGuidance: guidance.isEmpty ? null : guidance,
          muscleIds: _muscleIds,
        );
    if (mounted) context.pop(id);
  }

  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(exerciseRepositoryProvider);
    context.pop();
    await removeExerciseWithUndo(
      messenger: messenger,
      repository: repository,
      entry: widget.existing!,
    );
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if ((discard ?? false) && mounted) context.pop();
  }

  void _toggleMuscle(int muscleId) {
    _muscleIds.contains(muscleId)
        ? _muscleIds.remove(muscleId)
        : _muscleIds.add(muscleId);
    _markDirty();
  }

  @override
  Widget build(BuildContext context) {
    final muscles = ref.watch(musclesProvider).value ?? const [];
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.existing == null ? 'New exercise' : 'Edit exercise',
          ),
          actions: [
            if (widget.existing != null)
              IconButton(
                tooltip: 'Delete exercise',
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete,
              ),
            TextButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _title,
                autofocus: widget.existing == null,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  counterText: '',
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Give the exercise a title'
                    : null,
                onChanged: (_) => _markDirty(),
              ),
              const SizedBox(height: 24),
              Text('Tracking', style: textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in TrackingType.values)
                    ChoiceChip(
                      avatar: Icon(type.icon),
                      label: Text(type.label),
                      selected: type == _trackingType,
                      showCheckmark: false,
                      onSelected: (_) {
                        _trackingType = type;
                        _markDirty();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Muscles', style: textTheme.titleSmall),
              Text(
                'Tap in order of involvement. The first is the main muscle.',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final muscle in muscles)
                    FilterChip(
                      avatar: _muscleIds.contains(muscle.id)
                          ? CircleAvatar(
                              child: Text(
                                '${_muscleIds.indexOf(muscle.id) + 1}',
                              ),
                            )
                          : null,
                      label: Text(muscle.name),
                      selected: _muscleIds.contains(muscle.id),
                      showCheckmark: false,
                      onSelected: (_) => _toggleMuscle(muscle.id),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _formGuidance,
                minLines: 3,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Form guidance (optional)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _markDirty(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
