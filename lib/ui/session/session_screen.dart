import 'package:djym/data/database/app_database.dart';
import 'package:djym/data/repositories/settings_repository.dart';
import 'package:djym/data/repositories/workout_session_repository.dart';
import 'package:djym/domain/unit_system.dart';
import 'package:djym/routing/routes.dart';
import 'package:djym/ui/calendar/selected_day_provider.dart';
import 'package:djym/ui/core/clock_provider.dart';
import 'package:djym/ui/core/placeholder_body.dart';
import 'package:djym/ui/exercises/exercise_picker.dart';
import 'package:djym/ui/session/exercise_card.dart';
import 'package:djym/ui/session/rest_bar.dart';
import 'package:djym/ui/session/rest_timer.dart';
import 'package:djym/ui/session/session_summary_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({
    required this.sessionId,
    this.pickExercisesOnOpen = false,
    super.key,
  });

  final int sessionId;

  /// A fresh workout opens straight into the picker to save a tap.
  final bool pickExercisesOnOpen;

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  WorkoutSessionRepository get _repository =>
      ref.read(workoutSessionRepositoryProvider);

  @override
  void initState() {
    super.initState();
    if (widget.pickExercisesOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _addExercises());
    }
  }

  Future<void> _addExercises() async {
    final ids = await showExercisePicker(context);
    if (ids == null) return;
    await _repository.addExercises(widget.sessionId, ids);
  }

  Future<void> _reorder(
    List<SessionExercise> exercises,
    int oldIndex,
    int newIndex,
  ) {
    final reordered = [...exercises];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, moved);
    return _repository.reorderExercises(reordered);
  }

  Future<void> _finish(
    List<SessionExercise> exercises,
    UnitSystem units,
  ) async {
    final logged = exercises.any(
      (entry) => entry.sets.any((set) => set.hasValues),
    );
    if (!logged) {
      return _remove(
        title: 'Nothing logged yet',
        message: 'There is nothing to save. Discard this workout?',
        action: 'Discard',
      );
    }

    await ref.read(restTimerProvider.notifier).skipFor(widget.sessionId);
    final summary = await _repository.finishSession(widget.sessionId);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => SessionSummarySheet(summary: summary, units: units),
    );
    ref.read(selectedDayProvider.notifier).selectToday();
    if (mounted) context.go(Routes.calendar);
  }

  Future<void> _remove({
    required String title,
    required String message,
    required String action,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false) || !mounted) return;

    final repository = _repository;
    final restTimer = ref.read(restTimerProvider.notifier);
    context.go(Routes.calendar);
    await restTimer.skipFor(widget.sessionId);
    await repository.deleteSession(widget.sessionId);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider(widget.sessionId)).value;
    final exercises = ref
        .watch(sessionExercisesProvider(widget.sessionId))
        .value;
    final units =
        ref.watch(settingsProvider).value?.unitSystem ?? UnitSystem.metric;

    if (session == null || exercises == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final finished = session.finishedAt != null;
    final repository = _repository;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop && finished) {
          await repository.tidyFinishedSession(widget.sessionId);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: finished
              ? Text(
                  MaterialLocalizations.of(
                    context,
                  ).formatMediumDate(session.startedAt),
                )
              : _ElapsedTitle(session),
          actions: [
            if (finished)
              TextButton(onPressed: context.pop, child: const Text('Done'))
            else
              TextButton(
                onPressed: () => _finish(exercises, units),
                child: const Text('Finish'),
              ),
            PopupMenuButton<void>(
              tooltip: 'Workout options',
              itemBuilder: (_) => [
                if (finished)
                  PopupMenuItem(
                    onTap: () => _remove(
                      title: 'Delete workout?',
                      message: 'This workout and all its sets will be deleted.',
                      action: 'Delete',
                    ),
                    child: const Text('Delete workout'),
                  )
                else
                  PopupMenuItem(
                    onTap: () => _remove(
                      title: 'Discard workout?',
                      message:
                          'All sets logged in this workout will be deleted.',
                      action: 'Discard',
                    ),
                    child: const Text('Discard workout'),
                  ),
              ],
            ),
          ],
          bottom: finished ? _SessionTimes(session) : null,
        ),
        bottomNavigationBar: finished ? null : const RestBar(),
        body: exercises.isEmpty
            ? PlaceholderBody(
                icon: Icons.fitness_center,
                message: 'Add the exercises you are doing',
                action: FilledButton.icon(
                  onPressed: _addExercises,
                  icon: const Icon(Icons.add),
                  label: const Text('Add exercise'),
                ),
              )
            : ReorderableListView.builder(
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.only(top: 6),
                itemCount: exercises.length,
                onReorder: (oldIndex, newIndex) =>
                    _reorder(exercises, oldIndex, newIndex),
                itemBuilder: (context, index) => ExerciseCard(
                  key: ValueKey(exercises[index].exercise.id),
                  entry: exercises[index],
                  sessionId: widget.sessionId,
                  index: index,
                  units: units,
                ),
                footer: _SessionFooter(
                  session: session,
                  onAddExercise: _addExercises,
                ),
              ),
      ),
    );
  }
}

/// Start and end of a finished workout, both editable.
class _SessionTimes extends ConsumerWidget implements PreferredSizeWidget {
  const _SessionTimes(this.session);

  final WorkoutSession session;

  @override
  Size get preferredSize => const Size.fromHeight(48);

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref, {
    required bool start,
  }) async {
    final startedAt = session.startedAt;
    final finishedAt = session.finishedAt!;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start ? startedAt : finishedAt),
    );
    if (picked == null) return;

    DateTime on(DateTime day) =>
        DateTime(day.year, day.month, day.day, picked.hour, picked.minute);
    final newStart = start ? on(startedAt) : startedAt;
    var newEnd = start ? finishedAt : on(startedAt);
    if (!newEnd.isAfter(newStart)) {
      newEnd = start
          ? newStart.add(finishedAt.difference(startedAt))
          : newEnd.add(const Duration(days: 1));
    }
    await ref
        .read(workoutSessionRepositoryProvider)
        .updateSessionTimes(
          session.id,
          startedAt: newStart,
          finishedAt: newEnd,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = MaterialLocalizations.of(context);
    String time(DateTime value) =>
        localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value));
    final finishedAt = session.finishedAt!;
    final duration = finishedAt.difference(session.startedAt).inSeconds;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () => _pick(context, ref, start: true),
            icon: const Icon(Icons.schedule),
            label: Text('Start ${time(session.startedAt)}'),
          ),
          TextButton(
            onPressed: () => _pick(context, ref, start: false),
            child: Text('End ${time(finishedAt)}'),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(formatDuration(duration)),
          ),
        ],
      ),
    );
  }
}

class _ElapsedTitle extends ConsumerWidget {
  const _ElapsedTitle(this.session);

  final WorkoutSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final end = session.finishedAt ?? now;
    final elapsed = end.difference(session.startedAt).inSeconds;
    return Text('Workout · ${formatDuration(elapsed < 0 ? 0 : elapsed)}');
  }
}

class _SessionFooter extends ConsumerStatefulWidget {
  const _SessionFooter({required this.session, required this.onAddExercise});

  final WorkoutSession session;
  final VoidCallback onAddExercise;

  @override
  ConsumerState<_SessionFooter> createState() => _SessionFooterState();
}

class _SessionFooterState extends ConsumerState<_SessionFooter> {
  late final _notes = TextEditingController(text: widget.session.notes);

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          OutlinedButton.icon(
            onPressed: widget.onAddExercise,
            icon: const Icon(Icons.add),
            label: const Text('Add exercise'),
          ),
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Workout notes',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (notes) => ref
                .read(workoutSessionRepositoryProvider)
                .updateNotes(widget.session.id, notes),
          ),
        ],
      ),
    );
  }
}
