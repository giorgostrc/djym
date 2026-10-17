import 'package:flutter/material.dart';
import 'package:loggym/data/database/app_database.dart';
import 'package:loggym/data/repositories/workout_session_repository.dart';
import 'package:loggym/domain/unit_system.dart';
import 'package:loggym/ui/session/logged_set_tile.dart';
import 'package:loggym/ui/session/set_description.dart';

Future<void> showLastPerformance(
  BuildContext context, {
  required Exercise exercise,
  required LastPerformance last,
  required UnitSystem units,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => _LastPerformanceSheet(
    exercise: exercise,
    last: last,
    units: units,
  ),
);

class _LastPerformanceSheet extends StatelessWidget {
  const _LastPerformanceSheet({
    required this.exercise,
    required this.last,
    required this.units,
  });

  final Exercise exercise;
  final LastPerformance last;
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = MaterialLocalizations.of(context).formatFullDate(last.date);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exercise.title, style: theme.textTheme.titleLarge),
                  Text(
                    'Last time · $date',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: last.sets.length,
                separatorBuilder: (_, _) =>
                    const Divider(indent: 24, endIndent: 24, height: 1),
                itemBuilder: (context, index) => LoggedSetTile(
                  number: index + 1,
                  set: last.sets[index],
                  description: describeSet(
                    last.sets[index],
                    exercise.trackingType,
                    units,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
