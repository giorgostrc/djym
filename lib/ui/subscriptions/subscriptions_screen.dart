import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loggym/data/repositories/settings_repository.dart';
import 'package:loggym/data/repositories/subscription_repository.dart';
import 'package:loggym/domain/money.dart';
import 'package:loggym/routing/routes.dart';
import 'package:loggym/ui/core/placeholder_body.dart';
import 'package:loggym/ui/subscriptions/subscription_text.dart';

class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptions = ref.watch(subscriptionsProvider).value;
    final currency = ref.watch(settingsProvider).value?.currencyCode ?? 'EUR';
    final today = DateTime.now();
    void addSubscription() => context.push(Routes.newSubscription);

    return Scaffold(
      appBar: AppBar(title: const Text('Gym subscriptions')),
      floatingActionButton: subscriptions?.isEmpty ?? true
          ? null
          : FloatingActionButton.extended(
              heroTag: null,
              onPressed: addSubscription,
              icon: const Icon(Icons.add),
              label: const Text('Add subscription'),
            ),
      body: switch (subscriptions) {
        null => const Center(child: CircularProgressIndicator()),
        [] => PlaceholderBody(
          icon: Icons.card_membership,
          message: 'No gym subscriptions yet',
          action: FilledButton.icon(
            onPressed: addSubscription,
            icon: const Icon(Icons.add),
            label: const Text('Add subscription'),
          ),
        ),
        _ => ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 88),
          children: [
            for (final overview in subscriptions)
              ListTile(
                isThreeLine: true,
                title: Text(overview.subscription.title),
                subtitle: Text(
                  '${describeDateRange(overview.period)} · '
                  '${formatMoney(overview.subscription.costCents, currency)}'
                  '\n${describeSessions(overview.sessionCount)} · '
                  '${describeCostPerSession(overview, currency)} per session',
                ),
                trailing: overview.period.contains(today)
                    ? const Chip(label: Text('Current'))
                    : null,
                onTap: () => context.push(
                  Routes.subscription(overview.subscription.id),
                ),
              ),
          ],
        ),
      },
    );
  }
}
