/// A countdown between sets. [length] grows and shrinks with adjustments so
/// progress stays proportional.
class Rest {
  const Rest({required this.endsAt, required this.length});

  factory Rest.startingAt(DateTime now, Duration length) =>
      Rest(endsAt: now.add(length), length: length);

  final DateTime endsAt;
  final Duration length;

  Duration remainingAt(DateTime now) {
    final remaining = endsAt.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool isOverAt(DateTime now) => !now.isBefore(endsAt);

  double progressAt(DateTime now) => length <= Duration.zero
      ? 1
      : 1 - remainingAt(now).inMilliseconds / length.inMilliseconds;

  Rest adjustedBy(Duration delta) =>
      Rest(endsAt: endsAt.add(delta), length: length + delta);
}
