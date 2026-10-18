import 'package:djym/domain/subscription_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('month presets end the day before the same date next month', () {
    final monthly = SubscriptionPeriod.months(DateTime(2026, 10, 15), 1);
    final yearly = SubscriptionPeriod.months(DateTime(2026), 12);
    final fromMonthEnd = SubscriptionPeriod.months(DateTime(2026, 1, 31), 1);

    expect(monthly.end, DateTime(2026, 11, 14));
    expect(monthly.wholeMonths, 1);
    expect(yearly.end, DateTime(2026, 12, 31));
    expect(yearly.wholeMonths, 12);
    expect(fromMonthEnd.end, DateTime(2026, 2, 27));
    expect(
      SubscriptionPeriod(
        DateTime(2026, 10),
        DateTime(2026, 10, 20),
      ).wholeMonths,
      isNull,
    );
  });

  test('includes every moment of its first and last day', () {
    final period = SubscriptionPeriod(
      DateTime(2026, 10),
      DateTime(2026, 10, 31),
    );

    expect(period.contains(DateTime(2026, 10)), isTrue);
    expect(period.contains(DateTime(2026, 10, 31, 23, 59)), isTrue);
    expect(period.contains(DateTime(2026, 11)), isFalse);
    expect(period.contains(DateTime(2026, 9, 30, 23, 59)), isFalse);
    expect(period.lengthInDays, 31);
  });

  test('ends soon in its last seven days, across a clock change', () {
    final period = SubscriptionPeriod(
      DateTime(2026, 10),
      DateTime(2026, 10, 31),
    );

    expect(period.daysLeftOn(DateTime(2026, 10, 24)), 7);
    expect(period.endsSoonOn(DateTime(2026, 10, 24)), isFalse);
    expect(period.endsSoonOn(DateTime(2026, 10, 25, 22)), isTrue);
    expect(period.endsSoonOn(DateTime(2026, 10, 31)), isTrue);
    expect(period.endsSoonOn(DateTime(2026, 11)), isFalse);
    expect(period.hasEndedOn(DateTime(2026, 11)), isTrue);
  });

  test('renewing keeps the length and never starts in the past', () {
    final period = SubscriptionPeriod.months(DateTime(2026, 9, 15), 3);

    expect(
      period.renewedOn(DateTime(2026, 12, 10)).start,
      DateTime(2026, 12, 15),
    );
    final late = period.renewedOn(DateTime(2027, 1, 20));
    expect(late.start, DateTime(2027, 1, 20));
    expect(late.wholeMonths, 3);

    final custom = SubscriptionPeriod(
      DateTime(2026, 10),
      DateTime(2026, 10, 10),
    ).renewedOn(DateTime(2026, 10, 5));
    expect(custom.start, DateTime(2026, 10, 11));
    expect(custom.lengthInDays, 10);
  });
}
