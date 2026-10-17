import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loggym/data/database/app_database.dart';
import 'package:loggym/data/repositories/exercise_repository.dart';
import 'package:loggym/data/repositories/plan_repository.dart';
import 'package:loggym/routing/routes.dart';
import 'package:loggym/ui/exercises/exercise_avatar.dart';
import 'package:loggym/ui/exercises/exercise_picker.dart';

const _defaultTargetSets = 3;

class PlanEditorScreen extends ConsumerWidget {
  const PlanEditorScreen({this.planId, super.key});

  final int? planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (planId == null) return const _PlanEditor();

    final existing = ref
        .watch(plansProvider)
        .value
        ?.where((overview) => overview.plan.id == planId)
        .firstOrNull;
    if (existing == null) return const Scaffold();

    return _PlanEditor(existing: existing);
  }
}

class _Item {
  _Item(this.exercise, this.targetSets);

  final Exercise exercise;
  int targetSets;
}

class _PlanEditor extends ConsumerStatefulWidget {
  const _PlanEditor({this.existing});

  final PlanOverview? existing;

  @override
  ConsumerState<_PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends ConsumerState<_PlanEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.existing?.plan.name,
  );
  late final List<_Item> _items = [
    for (final item in widget.existing?.items ?? <PlanItem>[])
      _Item(item.exercise, item.targetSets),
  ];
  var _dirty = false;

  PlanRepository get _repository => ref.read(planRepositoryProvider);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _markDirty() => setState(() => _dirty = true);

  Future<void> _addExercises() async {
    final ids = await showExercisePicker(context);
    if (ids == null) return;
    final exercises = await ref
        .read(exerciseRepositoryProvider)
        .exercisesByIds(ids);
    _items.addAll([
      for (final exercise in exercises) _Item(exercise, _defaultTargetSets),
    ]);
    _markDirty();
  }

  void _remove(_Item item) {
    final index = _items.indexOf(item);
    _items.removeAt(index);
    _markDirty();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          persist: false,
          content: Text('${item.exercise.title} removed'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => setState(() => _items.insert(index, item)),
          ),
        ),
      );
  }

  void _reorder(int oldIndex, int newIndex) {
    final moved = _items.removeAt(oldIndex);
    _items.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, moved);
    _markDirty();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    await _repository.savePlan(
      id: widget.existing?.plan.id,
      name: _name.text.trim(),
      items: [
        for (final item in _items)
          (exerciseId: item.exercise.id, targetSets: item.targetSets),
      ],
    );
    if (mounted) context.pop();
  }

  Future<void> _duplicate() async {
    final copyId = await _repository.duplicatePlan(widget.existing!);
    if (mounted) context.pushReplacement(Routes.plan(copyId));
  }

  Future<void> _delete() async {
    final confirmed = await _confirm(
      title: 'Delete plan?',
      message: 'Workouts done with this plan are kept.',
      action: 'Delete',
    );
    if (!confirmed || !mounted) return;

    final repository = _repository;
    context.pop();
    await repository.deletePlan(widget.existing!.plan.id);
  }

  Future<bool> _confirm({
    required String title,
    required String action,
    String? message,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await _confirm(
          title: 'Discard changes?',
          action: 'Discard',
        );
        if (discard && context.mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.existing == null ? 'New plan' : 'Edit plan'),
          actions: [
            TextButton(onPressed: _save, child: const Text('Save')),
            if (widget.existing != null)
              PopupMenuButton<void>(
                tooltip: 'Plan options',
                itemBuilder: (_) => [
                  PopupMenuItem(
                    onTap: _duplicate,
                    child: const Text('Duplicate'),
                  ),
                  PopupMenuItem(
                    onTap: _delete,
                    child: const Text('Delete plan'),
                  ),
                ],
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.only(bottom: 32),
            header: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextFormField(
                controller: _name,
                autofocus: widget.existing == null,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Plan name',
                  hintText: 'e.g. Push day',
                  counterText: '',
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Give the plan a name'
                    : null,
                onChanged: (_) => _markDirty(),
              ),
            ),
            itemCount: _items.length,
            onReorder: _reorder,
            itemBuilder: (context, index) {
              final item = _items[index];
              return _PlanItemTile(
                key: ObjectKey(item),
                item: item,
                index: index,
                onRemove: () => _remove(item),
                onTargetSetsChanged: (sets) {
                  item.targetSets = sets;
                  _markDirty();
                },
              );
            },
            footer: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: OutlinedButton.icon(
                onPressed: _addExercises,
                icon: const Icon(Icons.add),
                label: const Text('Add exercises'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanItemTile extends StatelessWidget {
  const _PlanItemTile({
    required this.item,
    required this.index,
    required this.onRemove,
    required this.onTargetSetsChanged,
    super.key,
  });

  final _Item item;
  final int index;
  final VoidCallback onRemove;
  final ValueChanged<int> onTargetSetsChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final sets = item.targetSets;

    return Dismissible(
      key: ObjectKey(item),
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
      onDismissed: (_) => onRemove(),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 16, right: 4),
        leading: ExerciseAvatar(item.exercise),
        title: Text(item.exercise.title),
        subtitle: Text('$sets ${sets == 1 ? 'set' : 'sets'}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'One set fewer',
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: sets > 1 ? () => onTargetSetsChanged(sets - 1) : null,
            ),
            IconButton(
              tooltip: 'One set more',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => onTargetSetsChanged(sets + 1),
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
    );
  }
}
