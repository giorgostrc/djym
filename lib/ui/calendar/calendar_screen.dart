import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loggym/data/repositories/settings_repository.dart';
import 'package:loggym/data/repositories/workout_session_repository.dart';
import 'package:loggym/domain/unit_system.dart';
import 'package:loggym/routing/routes.dart';
import 'package:loggym/ui/calendar/selected_day_provider.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _focusedDay = ref.read(selectedDayProvider);

  DateTime get _focusedMonth => DateTime(_focusedDay.year, _focusedDay.month);

  Future<void> _startWorkout() async {
    final id = await ref.read(workoutSessionRepositoryProvider).startSession();
    if (mounted) await context.push(Routes.session(id, pickExercises: true));
  }

  Future<void> _logPastWorkout(DateTime day) async {
    final id = await ref
        .read(workoutSessionRepositoryProvider)
        .logPastSession(day);
    if (mounted) await context.push(Routes.session(id, pickExercises: true));
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = ref.watch(selectedDayProvider);
    final sessions =
        ref.watch(sessionsInMonthProvider(_focusedMonth)).value ?? const [];
    final daySessions = [
      for (final overview in sessions)
        if (isSameDay(overview.session.startedAt, selectedDay)) overview,
    ];
    final hasActiveSession = ref.watch(activeSessionProvider).value != null;
    final firstName = ref.watch(settingsProvider).value?.firstName?.trim();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    ref.listen(
      selectedDayProvider,
      (_, day) => setState(() => _focusedDay = day),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('LogGym')),
      floatingActionButton: switch (selectedDay.compareTo(today)) {
        < 0 => FloatingActionButton.extended(
          heroTag: null,
          onPressed: () => _logPastWorkout(selectedDay),
          icon: const Icon(Icons.edit_calendar),
          label: const Text('Log workout'),
        ),
        0 when !hasActiveSession => FloatingActionButton.extended(
          heroTag: null,
          onPressed: _startWorkout,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start workout'),
        ),
        _ => null,
      },
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          if (firstName != null && firstName.isNotEmpty)
            _Greeting(firstName: firstName),
          TableCalendar<SessionOverview>(
            firstDay: DateTime(2000),
            lastDay: DateTime(2100),
            focusedDay: _focusedDay,
            startingDayOfWeek: StartingDayOfWeek.monday,
            availableCalendarFormats: const {CalendarFormat.month: 'Month'},
            calendarStyle: const CalendarStyle(markersMaxCount: 3),
            selectedDayPredicate: (day) => isSameDay(day, selectedDay),
            eventLoader: (day) => [
              for (final overview in sessions)
                if (isSameDay(overview.session.startedAt, day)) overview,
            ],
            onDaySelected: (day, focusedDay) {
              ref.read(selectedDayProvider.notifier).select(day);
              setState(() => _focusedDay = focusedDay);
            },
            onPageChanged: (focusedDay) =>
                setState(() => _focusedDay = focusedDay),
          ),
          const Divider(),
          _DayHeader(day: selectedDay),
          if (daySessions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'No workouts',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final overview in daySessions)
              _SessionTile(
                overview: overview,
                onTap: () =>
                    context.push(Routes.sessionDetail(overview.session.id)),
              ),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.firstName});

  final String firstName;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final partOfDay = hour < 12
        ? 'morning'
        : hour < 18
        ? 'afternoon'
        : 'evening';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        'Good $partOfDay, $firstName',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final label = isSameDay(day, DateTime.now())
        ? 'Today'
        : MaterialLocalizations.of(context).formatFullDate(day);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.overview, required this.onTap});

  final SessionOverview overview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final session = overview.session;
    final start = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(session.startedAt));
    final duration = formatDuration(
      session.finishedAt!.difference(session.startedAt).inSeconds,
    );
    final sets = overview.setCount == 1 ? '1 set' : '${overview.setCount} sets';

    return Card.outlined(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.fitness_center),
        title: Text(
          overview.exerciseTitles.isEmpty
              ? 'Workout'
              : overview.exerciseTitles.join(', '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('$start · $duration · $sets'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
