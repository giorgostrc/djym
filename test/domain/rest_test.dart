import 'package:flutter_test/flutter_test.dart';
import 'package:loggym/domain/rest.dart';

void main() {
  final start = DateTime(2026, 10, 18, 18);
  final rest = Rest.startingAt(start, const Duration(minutes: 3));

  test('counts down from its length', () {
    final later = start.add(const Duration(seconds: 45));

    expect(rest.remainingAt(start), const Duration(minutes: 3));
    expect(rest.remainingAt(later), const Duration(minutes: 2, seconds: 15));
    expect(rest.progressAt(later), 0.25);
    expect(rest.isOverAt(later), isFalse);
  });

  test('is over at its end and never goes negative', () {
    final end = start.add(const Duration(minutes: 3));
    final after = end.add(const Duration(seconds: 10));

    expect(rest.isOverAt(end), isTrue);
    expect(rest.remainingAt(after), Duration.zero);
    expect(rest.progressAt(after), 1);
  });

  test('adjusting moves the end and the length together', () {
    final longer = rest.adjustedBy(const Duration(seconds: 15));
    final shorter = rest.adjustedBy(const Duration(seconds: -15));

    expect(longer.remainingAt(start), const Duration(minutes: 3, seconds: 15));
    expect(longer.progressAt(start), 0);
    expect(shorter.remainingAt(start), const Duration(minutes: 2, seconds: 45));
  });
}
