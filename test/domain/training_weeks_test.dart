import 'package:flutter_test/flutter_test.dart';
import 'package:loggym/domain/training_weeks.dart';

void main() {
  test('weeks start on Monday', () {
    expect(weekStart(DateTime(2026, 10, 18, 20)), DateTime(2026, 10, 12));
    expect(weekStart(DateTime(2026, 10, 12)), DateTime(2026, 10, 12));
  });

  test('the best streak counts consecutive weeks, across a clock change', () {
    expect(longestWeekStreak([]), 0);
    expect(
      longestWeekStreak([
        DateTime(2026, 10, 13),
        DateTime(2026, 10, 15),
        DateTime(2026, 10, 20),
        DateTime(2026, 10, 27),
        DateTime(2026, 11, 3),
        DateTime(2026, 11, 24),
      ]),
      4,
    );
  });
}
