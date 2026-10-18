import 'package:intl/intl.dart';
import 'package:loggym/data/repositories/subscription_repository.dart';
import 'package:loggym/domain/money.dart';
import 'package:loggym/domain/subscription_period.dart';

String describeDateRange(SubscriptionPeriod period) {
  final sameYear = period.start.year == period.end.year;
  final start = (sameYear ? DateFormat.MMMd() : DateFormat.yMMMd()).format(
    period.start,
  );
  return '$start – ${DateFormat.yMMMd().format(period.end)}';
}

String describeSessions(int count) =>
    count == 1 ? '1 session' : '$count sessions';

String describeCostPerSession(
  SubscriptionOverview overview,
  String currencyCode,
) {
  final cents = overview.costPerSessionCents;
  return cents == null ? '—' : formatMoney(cents, currencyCode);
}

/// Where the period stands on [today], e.g. "Ends in 5 days".
String describeStatus(SubscriptionPeriod period, DateTime today) {
  if (!period.hasStartedOn(today)) {
    final days = daysBetween(today, period.start);
    return days == 1 ? 'Starts tomorrow' : 'Starts in $days days';
  }
  if (period.hasEndedOn(today)) {
    return 'Ended ${DateFormat.MMMd().format(period.end)}';
  }
  final left = period.daysLeftOn(today);
  if (period.endsSoonOn(today)) {
    return switch (left) {
      0 => 'Ends today',
      1 => 'Ends tomorrow',
      _ => 'Ends in $left days',
    };
  }
  return '$left days left · until ${DateFormat.MMMd().format(period.end)}';
}
