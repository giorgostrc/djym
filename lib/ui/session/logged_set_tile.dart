import 'package:djym/data/database/app_database.dart';
import 'package:flutter/material.dart';

/// A read-only set with its comment, as shown in history.
class LoggedSetTile extends StatelessWidget {
  const LoggedSetTile({
    required this.number,
    required this.set,
    required this.description,
    super.key,
  });

  final int number;
  final ExerciseSet set;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comment = set.comment;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: theme.colorScheme.secondaryContainer,
            child: Text('$number', style: theme.textTheme.labelLarge),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(description, style: theme.textTheme.titleMedium),
                if (comment != null)
                  Text(
                    comment,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
