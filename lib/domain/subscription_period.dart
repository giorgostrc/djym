import 'dart:math';

/// Whole days from [start] through [end], both included.
class SubscriptionPeriod {
  SubscriptionPeriod(DateTime start, DateTime end)
    : start = dateOnly(start),
      end = dateOnly(end);

  factory SubscriptionPeriod.months(DateTime start, int months) {
    final next = addMonths(dateOnly(start), months);
    return SubscriptionPeriod(
      start,
      DateTime(next.year, next.month, next.day - 1),
    );
  }

  final DateTime start;
  final DateTime end;

  DateTime get _dayAfterEnd => DateTime(end.year, end.month, end.day + 1);

  int get lengthInDays => daysBetween(start, end) + 1;

  /// The number of months when the period is exactly that, as presets make.
  int? get wholeMonths {
    final months = (end.year - start.year) * 12 + end.month - start.month;
    for (final candidate in [months, months + 1]) {
      if (candidate > 0 &&
          SubscriptionPeriod.months(start, candidate).end == end) {
        return candidate;
      }
    }
    return null;
  }

  bool contains(DateTime moment) =>
      !moment.isBefore(start) && moment.isBefore(_dayAfterEnd);

  bool hasEndedOn(DateTime day) => !dateOnly(day).isBefore(_dayAfterEnd);

  bool hasStartedOn(DateTime day) => !dateOnly(day).isBefore(start);

  int daysLeftOn(DateTime day) => daysBetween(day, end);

  /// True in the last seven days, the end day included.
  bool endsSoonOn(DateTime day) {
    final left = daysLeftOn(day);
    return left >= 0 && left < 7;
  }

  double progressOn(DateTime day) =>
      ((daysBetween(start, day) + 1) / lengthInDays).clamp(0, 1).toDouble();

  /// The same length again, starting the day after this one ends or [today],
  /// whichever is later.
  SubscriptionPeriod renewedOn(DateTime today) {
    final dayAfterEnd = _dayAfterEnd;
    final from = dateOnly(today).isAfter(dayAfterEnd)
        ? dateOnly(today)
        : dayAfterEnd;
    final months = wholeMonths;
    return months == null
        ? SubscriptionPeriod(
            from,
            DateTime(from.year, from.month, from.day + lengthInDays - 1),
          )
        : SubscriptionPeriod.months(from, months);
  }
}

DateTime dateOnly(DateTime moment) {
  final local = moment.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Calendar days from [from] to [to], unaffected by daylight saving shifts.
int daysBetween(DateTime from, DateTime to) {
  final a = dateOnly(from);
  final b = dateOnly(to);
  return DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}

/// Same day of the month [months] later, clamped to the month's last day.
DateTime addMonths(DateTime day, int months) {
  final lastDay = DateTime(day.year, day.month + months + 1, 0).day;
  return DateTime(day.year, day.month + months, min(day.day, lastDay));
}
