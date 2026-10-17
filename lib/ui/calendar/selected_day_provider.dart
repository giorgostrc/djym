import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectedDay extends Notifier<DateTime> {
  @override
  DateTime build() => _today();

  void select(DateTime day) => state = DateTime(day.year, day.month, day.day);

  void selectToday() => state = _today();

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

/// Lives outside the calendar so finishing a workout can jump it to today.
final selectedDayProvider = NotifierProvider<SelectedDay, DateTime>(
  SelectedDay.new,
);
