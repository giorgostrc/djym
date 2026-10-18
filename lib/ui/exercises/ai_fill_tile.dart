import 'package:flutter/material.dart';

class AiFillTile extends StatelessWidget {
  const AiFillTile({
    required this.title,
    required this.filling,
    required this.onTap,
    super.key,
  });

  final String title;
  final bool filling;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card.outlined(
      margin: const EdgeInsets.only(top: 8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        enabled: !filling,
        leading: Icon(Icons.auto_awesome, color: colors.primary),
        title: Text(filling ? 'Filling with AI…' : 'Fill with AI'),
        subtitle: Text(
          'Tracking, muscles and form cues for "$title"',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: filling
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
