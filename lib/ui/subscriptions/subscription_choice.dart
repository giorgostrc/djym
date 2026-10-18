import 'package:djym/data/repositories/subscription_repository.dart';
import 'package:djym/data/repositories/workout_session_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Picks which running subscription a workout counts towards. Hidden while
/// fewer than [minimumOptions] subscriptions ran on its day.
class SubscriptionChoice extends ConsumerWidget {
  const SubscriptionChoice({
    required this.sessionId,
    this.minimumOptions = 1,
    super.key,
  });

  final int sessionId;
  final int minimumOptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider(sessionId)).value;
    final subscriptions = ref.watch(subscriptionsProvider).value;
    if (session == null || subscriptions == null) {
      return const SizedBox.shrink();
    }

    final options = [
      for (final overview in subscriptions.reversed)
        if (overview.period.contains(session.startedAt) ||
            overview.subscription.id == session.subscriptionId)
          overview.subscription,
    ];
    if (options.length < minimumOptions) return const SizedBox.shrink();

    final repository = ref.read(subscriptionRepositoryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Text('Counts towards', style: Theme.of(context).textTheme.labelLarge),
        Wrap(
          spacing: 8,
          children: [
            for (final subscription in options)
              ChoiceChip(
                label: Text(subscription.title),
                selected: session.subscriptionId == subscription.id,
                onSelected: (_) =>
                    repository.linkSession(sessionId, subscription.id),
              ),
            ChoiceChip(
              label: const Text('None'),
              selected: session.subscriptionId == null,
              onSelected: (_) => repository.linkSession(sessionId, null),
            ),
          ],
        ),
      ],
    );
  }
}
