import 'package:djym/data/repositories/settings_repository.dart';
import 'package:djym/data/repositories/subscription_repository.dart';
import 'package:djym/domain/money.dart';
import 'package:djym/routing/routes.dart';
import 'package:djym/ui/subscriptions/subscription_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The Calendar's subscription cards, or a way to add the first one.
class SubscriptionSection extends ConsumerWidget {
  const SubscriptionSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptions = ref.watch(subscriptionsProvider).value;
    if (subscriptions == null) return const SizedBox.shrink();

    final featured = featuredSubscriptions(subscriptions, DateTime.now());
    if (featured.isEmpty) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextButton.icon(
            onPressed: () => context.push(
              subscriptions.isEmpty
                  ? Routes.newSubscription
                  : Routes.subscriptions,
            ),
            icon: const Icon(Icons.card_membership),
            label: Text(
              subscriptions.isEmpty
                  ? 'Track your gym subscription'
                  : 'Gym subscriptions',
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        children: [
          for (final overview in featured)
            _SubscriptionCard(
              overview: overview,
              renewable: !isRenewed(overview, subscriptions),
            ),
        ],
      ),
    );
  }
}

class _SubscriptionCard extends ConsumerWidget {
  const _SubscriptionCard({required this.overview, required this.renewable});

  final SubscriptionOverview overview;
  final bool renewable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final currency = ref.watch(settingsProvider).value?.currencyCode ?? 'EUR';
    final today = DateTime.now();
    final period = overview.period;
    final needsAttention = period.endsSoonOn(today) || period.hasEndedOn(today);

    return Card.outlined(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.subscriptions),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Row(
                spacing: 12,
                children: [
                  Icon(Icons.card_membership, color: colors.primary),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          overview.subscription.title,
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          describeStatus(period, today),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: needsAttention
                                ? colors.error
                                : colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (needsAttention && renewable)
                    TextButton(
                      onPressed: () => context.push(
                        Routes.renewSubscription(overview.subscription.id),
                      ),
                      child: const Text('Renew'),
                    )
                  else
                    const Icon(Icons.chevron_right),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: LinearProgressIndicator(
                  value: period.progressOn(today),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Row(
                children: [
                  _Stat(
                    value: '${overview.sessionCount}',
                    label: overview.sessionCount == 1 ? 'session' : 'sessions',
                  ),
                  _Stat(
                    value: describeCostPerSession(overview, currency),
                    label: 'per session',
                  ),
                  _Stat(
                    value: formatMoney(
                      overview.subscription.costCents,
                      currency,
                    ),
                    label: 'paid',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: theme.textTheme.titleMedium),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
