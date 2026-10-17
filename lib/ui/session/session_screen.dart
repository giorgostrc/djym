import 'package:flutter/material.dart';
import 'package:loggym/ui/core/placeholder_body.dart';

class SessionScreen extends StatelessWidget {
  const SessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New session')),
      body: const PlaceholderBody(
        icon: Icons.fitness_center,
        message: 'Add exercises from a plan or one by one',
      ),
    );
  }
}
