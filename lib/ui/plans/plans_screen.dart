import 'package:djym/data/repositories/plan_repository.dart';
import 'package:djym/routing/routes.dart';
import 'package:djym/ui/core/placeholder_body.dart';
import 'package:djym/ui/session/start_workout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(plansProvider).value;
    void createPlan() => context.push(Routes.newPlan);

    return Scaffold(
      appBar: AppBar(title: const Text('Workout plans')),
      floatingActionButton: plans?.isEmpty ?? true
          ? null
          : FloatingActionButton.extended(
              heroTag: null,
              onPressed: createPlan,
              icon: const Icon(Icons.add),
              label: const Text('New plan'),
            ),
      body: switch (plans) {
        null => const Center(child: CircularProgressIndicator()),
        [] => PlaceholderBody(
          icon: Icons.list_alt,
          message: 'No workout plans yet',
          action: FilledButton.icon(
            onPressed: createPlan,
            icon: const Icon(Icons.add),
            label: const Text('Create a plan'),
          ),
        ),
        _ => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
          children: [
            for (final overview in plans)
              _PlanCard(
                overview: overview,
                onOpen: () => context.push(Routes.plan(overview.plan.id)),
                onStart: () =>
                    startWorkout(context, ref, planId: overview.plan.id),
              ),
          ],
        ),
      },
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.overview,
    required this.onOpen,
    required this.onStart,
  });

  final PlanOverview overview;
  final VoidCallback onOpen;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exerciseNames = [
      for (final item in overview.items) item.exercise.title,
    ].join(', ');

    return Card.outlined(
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            spacing: 12,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      overview.plan.name,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      describePlanSize(overview),
                      style: theme.textTheme.bodySmall,
                    ),
                    if (exerciseNames.isNotEmpty)
                      Text(
                        exerciseNames,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
