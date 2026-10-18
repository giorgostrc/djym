import 'package:djym/data/database/app_database.dart';
import 'package:djym/data/repositories/workout_session_repository.dart';
import 'package:djym/domain/tracking_type.dart';
import 'package:djym/domain/unit_system.dart';
import 'package:djym/ui/core/text_input.dart';
import 'package:djym/ui/session/rest_timer.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One editable set. Every change is written straight to the database, so
/// the controllers are seeded once and never reset from later rebuilds.
class SetRow extends ConsumerStatefulWidget {
  const SetRow({
    required this.set,
    required this.number,
    required this.trackingType,
    required this.units,
    super.key,
  });

  final ExerciseSet set;
  final int number;
  final TrackingType trackingType;
  final UnitSystem units;

  @override
  ConsumerState<SetRow> createState() => _SetRowState();
}

class _SetRowState extends ConsumerState<SetRow> {
  late final _weight = TextEditingController(
    text: _format(widget.set.weightKg, widget.units.weightFromKg),
  );
  late final _reps = TextEditingController(text: widget.set.reps?.toString());
  late final _duration = TextEditingController(
    text: widget.set.durationSeconds == null
        ? null
        : formatDuration(widget.set.durationSeconds!),
  );
  late final _distance = TextEditingController(
    text: _format(widget.set.distanceMeters, widget.units.distanceFromMetres),
  );
  late final _comment = TextEditingController(text: widget.set.comment);
  late bool _showComment = widget.set.comment?.isNotEmpty ?? false;

  static String? _format(double? value, double Function(double) convert) =>
      value == null ? null : formatNumber(convert(value), decimals: 2);

  @override
  void dispose() {
    for (final controller in [_weight, _reps, _duration, _distance, _comment]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _write(ExerciseSetsCompanion changes) => ref
      .read(workoutSessionRepositoryProvider)
      .updateSet(widget.set.id, changes);

  Future<void> _toggleDone() async {
    final completing = widget.set.completedAt == null;
    await _write(
      ExerciseSetsCompanion(
        completedAt: Value(completing ? DateTime.now() : null),
      ),
    );
    if (completing && mounted) {
      await startRestAfterSet(context, ref, widget.set.sessionId);
    }
  }

  Future<void> _delete() async {
    final repository = ref.read(workoutSessionRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    await repository.deleteSets([widget.set]);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          persist: false,
          content: Text('Set ${widget.number} deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => repository.restoreSets([widget.set]),
          ),
        ),
      );
  }

  Future<void> _commentChanged(String text) async {
    setState(() {});
    await _write(
      ExerciseSetsCompanion(comment: Value(text.trim().isEmpty ? null : text)),
    );
  }

  Widget _weightField() => _NumberField(
    controller: _weight,
    label: widget.units.weightUnit,
    decimal: true,
    onChanged: (text) {
      final weight = parseDecimal(text);
      return _write(
        ExerciseSetsCompanion(
          weightKg: Value(
            weight == null ? null : widget.units.weightToKg(weight),
          ),
        ),
      );
    },
  );

  Widget _repsField() => _NumberField(
    controller: _reps,
    label: 'reps',
    onChanged: (text) =>
        _write(ExerciseSetsCompanion(reps: Value(int.tryParse(text)))),
  );

  Widget _durationField() => _NumberField(
    controller: _duration,
    label: 'time',
    hint: 'm:ss',
    allowColon: true,
    onChanged: (text) => _write(
      ExerciseSetsCompanion(durationSeconds: Value(parseDuration(text))),
    ),
  );

  Widget _distanceField() => _NumberField(
    controller: _distance,
    label: widget.units.distanceUnit,
    decimal: true,
    onChanged: (text) {
      final distance = parseDecimal(text);
      return _write(
        ExerciseSetsCompanion(
          distanceMeters: Value(
            distance == null ? null : widget.units.distanceToMetres(distance),
          ),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final done = widget.set.completedAt != null;
    final hasComment = _comment.text.isNotEmpty;

    final fields = switch (widget.trackingType) {
      TrackingType.weightReps => [_weightField(), _repsField()],
      TrackingType.reps => [_repsField()],
      TrackingType.duration => [_durationField()],
      TrackingType.distanceDuration => [_distanceField(), _durationField()],
    };

    return Dismissible(
      key: ValueKey(widget.set.id),
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
        await _delete();
        return true;
      },
      child: ColoredBox(
        color: done ? colors.secondaryContainer : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
          child: Column(
            children: [
              Row(
                spacing: 8,
                children: [
                  SizedBox(
                    width: 20,
                    child: Text(
                      '${widget.number}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  for (final field in fields) Expanded(child: field),
                  IconButton(
                    tooltip: 'Comment',
                    icon: Icon(
                      hasComment
                          ? Icons.mode_comment
                          : Icons.add_comment_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _showComment = !_showComment),
                  ),
                  IconButton(
                    tooltip: done ? 'Mark set not done' : 'Mark set done',
                    isSelected: done,
                    icon: const Icon(Icons.check_circle_outline),
                    selectedIcon: Icon(
                      Icons.check_circle,
                      color: colors.primary,
                    ),
                    onPressed: _toggleDone,
                  ),
                ],
              ),
              if (_showComment)
                Padding(
                  padding: const EdgeInsets.only(left: 28, right: 12, top: 4),
                  child: TextField(
                    controller: _comment,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Comment on this set',
                      suffixIcon: clearButton(
                        _comment,
                        onChanged: _commentChanged,
                      ),
                    ),
                    onChanged: _commentChanged,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberField extends StatefulWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.hint,
    this.decimal = false,
    this.allowColon = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool decimal;
  final bool allowColon;
  final Future<void> Function(String) onChanged;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final _focusNode = SelectAllFocusNode(widget.controller);

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allowColon = widget.allowColon;
    final decimal = widget.decimal;

    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.titleMedium,
      textInputAction: TextInputAction.next,
      keyboardType: allowColon
          ? TextInputType.datetime
          : TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(allowColon ? '[0-9:]' : (decimal ? '[0-9.,]' : '[0-9]')),
        ),
      ],
      decoration: InputDecoration(
        isDense: true,
        labelText: widget.label,
        hintText: widget.hint,
        border: const OutlineInputBorder(),
      ),
      onChanged: widget.onChanged,
    );
  }
}
