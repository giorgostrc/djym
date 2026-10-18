import 'dart:math';

import 'package:djym/domain/subscription_period.dart';

/// Monday of the week [day] falls in.
DateTime weekStart(DateTime day) {
  final date = dateOnly(day);
  return DateTime(date.year, date.month, date.day - (date.weekday - 1));
}

/// Most consecutive weeks with at least one of [days] in each.
int longestWeekStreak(Iterable<DateTime> days) {
  final weeks = {for (final day in days) weekStart(day)}.toList()..sort();
  var longest = 0;
  var current = 0;
  DateTime? previous;
  for (final week in weeks) {
    current = previous != null && daysBetween(previous, week) == 7
        ? current + 1
        : 1;
    longest = max(longest, current);
    previous = week;
  }
  return longest;
}
