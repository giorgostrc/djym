import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loggym/data/repositories/plan_repository.dart';
import 'package:loggym/data/repositories/workout_session_repository.dart';
import 'package:loggym/routing/routes.dart';

/// Starts today's workout, or offers to resume the one already running.
/// An empty workout opens straight into the exercise picker.
Future<void> startWorkout(
  BuildContext context,
  WidgetRef ref, {
  int? planId,
}) async {
  final active = ref.read(activeSessionProvider).value;
  if (active != null) {
    final resume = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Workout in progress'),
        content: const Text('Finish or discard it before starting another.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Resume'),
          ),
        ],
      ),
    );
    if ((resume ?? false) && context.mounted) {
      await context.push(Routes.session(active.id));
    }
    return;
  }

  final id = await ref
      .read(workoutSessionRepositoryProvider)
      .startSession(planId: planId);
  if (context.mounted) {
    await context.push(Routes.session(id, pickExercises: planId == null));
  }
}

/// Asks how to start when plans exist; null means the sheet was dismissed.
Future<({int? planId})?> chooseWorkoutStart(
  BuildContext context,
  List<PlanOverview> plans,
) async {
  if (plans.isEmpty) return (planId: null);

  return showModalBottomSheet<({int? planId})>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Empty workout'),
              subtitle: const Text('Pick exercises as you go'),
              onTap: () => Navigator.pop(context, (planId: null)),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'From a plan',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            for (final overview in plans)
              ListTile(
                leading: const Icon(Icons.list_alt),
                title: Text(overview.plan.name),
                subtitle: Text(describePlanSize(overview)),
                onTap: () => Navigator.pop(context, (planId: overview.plan.id)),
              ),
          ],
        ),
      ),
    ),
  );
}

String describePlanSize(PlanOverview overview) {
  final exercises = overview.items.length;
  final sets = overview.totalSets;
  return '$exercises ${exercises == 1 ? 'exercise' : 'exercises'} · '
      '$sets ${sets == 1 ? 'set' : 'sets'}';
}
