import 'package:flutter/material.dart';
import 'package:loggym/ui/core/placeholder_body.dart';

class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workout plans')),
      body: const PlaceholderBody(
        icon: Icons.list_alt,
        message: 'No workout plans yet',
      ),
    );
  }
}
