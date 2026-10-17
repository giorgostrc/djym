import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loggym/data/database/app_database.dart';
import 'package:loggym/data/repositories/workout_session_repository.dart';
import 'package:loggym/routing/routes.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();

  DateTime get _focusedMonth => DateTime(_focusedDay.year, _focusedDay.month);

  @override
  Widget build(BuildContext context) {
    final sessions =
        ref.watch(sessionsInMonthProvider(_focusedMonth)).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('LogGym')),
      body: TableCalendar<WorkoutSession>(
        firstDay: DateTime(2000),
        lastDay: DateTime(2100),
        focusedDay: _focusedDay,
        startingDayOfWeek: StartingDayOfWeek.monday,
        availableCalendarFormats: const {CalendarFormat.month: 'Month'},
        eventLoader: (day) => sessions
            .where((session) => isSameDay(session.startedAt, day))
            .toList(),
        onPageChanged: (focusedDay) => setState(() => _focusedDay = focusedDay),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.newSession),
        icon: const Icon(Icons.add),
        label: const Text('Log session'),
      ),
    );
  }
}
