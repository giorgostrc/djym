import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loggym/domain/unit_system.dart';
import 'package:loggym/ui/core/clock_provider.dart';
import 'package:loggym/ui/session/rest_timer.dart';

const _step = Duration(seconds: 15);

/// Whole seconds left, rounded up so a rest reads 3:00 as it starts and
/// 0:01 just before it ends.
String formatRestLeft(Duration remaining) =>
    formatDuration((remaining.inMilliseconds / 1000).ceil());

/// Sits at the bottom of a running workout while a rest counts down.
class RestBar extends ConsumerWidget {
  const RestBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rest = ref.watch(runningRestProvider);
    if (rest == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    ref.watch(clockProvider);
    final now = DateTime.now();
    final timer = ref.read(restTimerProvider.notifier);

    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: rest.progressAt(now)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rest', style: theme.textTheme.labelMedium),
                        Text(
                          formatRestLeft(rest.remainingAt(now)),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => timer.adjust(-_step),
                    child: const Text('−15 s'),
                  ),
                  TextButton(
                    onPressed: () => timer.adjust(_step),
                    child: const Text('+15 s'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton.tonal(
                    onPressed: timer.skip,
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
