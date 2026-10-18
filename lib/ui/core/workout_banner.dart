import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loggym/data/repositories/workout_session_repository.dart';
import 'package:loggym/domain/unit_system.dart';
import 'package:loggym/routing/routes.dart';
import 'package:loggym/ui/core/clock_provider.dart';
import 'package:loggym/ui/session/rest_bar.dart';
import 'package:loggym/ui/session/rest_timer.dart';

/// Shown above the tab bar on every tab while a workout runs.
class WorkoutBanner extends ConsumerWidget {
  const WorkoutBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider).value;
    if (session == null) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final elapsed = now.difference(session.startedAt).inSeconds;
    final rest = ref.watch(runningRestProvider);
    final restLeft = rest?.remainingAt(DateTime.now());

    return Material(
      color: colors.primaryContainer,
      child: InkWell(
        onTap: () => context.push(Routes.session(session.id)),
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              spacing: 12,
              children: [
                Icon(
                  rest == null ? Icons.fitness_center : Icons.timer_outlined,
                  color: colors.onPrimaryContainer,
                ),
                Expanded(
                  child: Text(
                    restLeft == null
                        ? 'Workout in progress · '
                              '${formatDuration(elapsed < 0 ? 0 : elapsed)}'
                        : 'Resting · ${formatRestLeft(restLeft)}',
                    style: TextStyle(color: colors.onPrimaryContainer),
                  ),
                ),
                Icon(Icons.chevron_right, color: colors.onPrimaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
