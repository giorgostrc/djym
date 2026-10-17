import 'package:flutter/material.dart';

class PlaceholderBody extends StatelessWidget {
  const PlaceholderBody({
    required this.icon,
    required this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          Icon(icon, size: 48, color: colors.outline),
          Text(message, style: TextStyle(color: colors.onSurfaceVariant)),
          ?action,
        ],
      ),
    );
  }
}
