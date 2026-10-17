import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ticks every second so elapsed times stay current; tests replace it.
final clockProvider = StreamProvider<DateTime>(
  (ref) => Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
);
