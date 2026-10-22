import 'package:djym/data/repositories/settings_repository.dart';
import 'package:djym/data/repositories/workout_session_repository.dart';
import 'package:djym/domain/unit_system.dart';
import 'package:djym/routing/routes.dart';
import 'package:djym/ui/exercises/exercise_avatar.dart';
import 'package:djym/ui/history/workout_share.dart';
import 'package:djym/ui/session/logged_set_tile.dart';
import 'package:djym/ui/session/set_description.dart';
import 'package:djym/ui/subscriptions/subscription_choice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Read-only look at a finished workout, with Edit and Delete.
class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({required this.sessionId, super.key});

  final int sessionId;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete workout?'),
        content: const Text('This workout and all its sets will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false) || !context.mounted) return;

    final repository = ref.read(workoutSessionRepositoryProvider);
    context.pop();
    await repository.deleteSession(sessionId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider(sessionId)).value;
    final exercises = ref.watch(sessionExercisesProvider(sessionId)).value;
    final units =
        ref.watch(settingsProvider).value?.unitSystem ?? UnitSystem.metric;
    if (session == null || exercises == null) return const Scaffold();

    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    String time(DateTime value) =>
        localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value));
    final finishedAt = session.finishedAt ?? session.startedAt;
    final duration = finishedAt.difference(session.startedAt).inSeconds;
    final notes = session.notes?.trim() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.formatMediumDate(session.startedAt)),
        actions: [
          IconButton(
            tooltip: 'Share workout',
            icon: Icon(Icons.adaptive.share),
            onPressed: () => showWorkoutShare(
              context,
              session: session,
              exercises: exercises,
              units: units,
            ),
          ),
          IconButton(
            tooltip: 'Edit workout',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(Routes.session(sessionId)),
          ),
          IconButton(
            tooltip: 'Delete workout',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: Text(
              '${time(session.startedAt)} – ${time(finishedAt)} · '
              '${formatDuration(duration)}',
              style: theme.textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: SubscriptionChoice(sessionId: sessionId),
          ),
          if (notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                notes,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          for (final entry in exercises) ...[
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: ExerciseAvatar(entry.exercise),
              title: Text(
                entry.exercise.title,
                style: theme.textTheme.titleMedium,
              ),
            ),
            for (final (index, set) in entry.sets.indexed)
              LoggedSetTile(
                number: index + 1,
                set: set,
                description: describeSet(
                  set,
                  entry.exercise.trackingType,
                  units,
                ),
              ),
            const Divider(indent: 24, endIndent: 24),
          ],
        ],
      ),
    );
  }
}
