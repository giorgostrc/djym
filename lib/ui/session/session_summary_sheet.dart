import 'package:djym/data/repositories/workout_session_repository.dart';
import 'package:djym/domain/unit_system.dart';
import 'package:djym/ui/subscriptions/subscription_choice.dart';
import 'package:flutter/material.dart';

class SessionSummarySheet extends StatelessWidget {
  const SessionSummarySheet({
    required this.summary,
    required this.units,
    super.key,
  });

  final SessionSummary summary;
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final stats = [
      ('Duration', formatDuration(summary.duration.inSeconds)),
      ('Exercises', '${summary.exerciseCount}'),
      ('Sets', '${summary.setCount}'),
      if (summary.volumeKg > 0)
        (
          'Volume',
          '${formatNumber(units.weightFromKg(summary.volumeKg), decimals: 0)} '
              '${units.weightUnit}',
        ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            Text('Workout complete', style: textTheme.headlineSmall),
            Wrap(
              spacing: 32,
              runSpacing: 16,
              children: [
                for (final (label, value) in stats)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(value, style: textTheme.titleLarge),
                      Text(label, style: textTheme.bodySmall),
                    ],
                  ),
              ],
            ),
            SubscriptionChoice(
              sessionId: summary.session.id,
              minimumOptions: 2,
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
