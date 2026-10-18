import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loggym/data/repositories/plan_repository.dart';
import 'package:loggym/data/repositories/workout_session_repository.dart';
import 'package:loggym/domain/unit_system.dart';
import 'package:loggym/routing/routes.dart';
import 'package:loggym/ui/calendar/selected_day_provider.dart';
import 'package:loggym/ui/calendar/year_view.dart';
import 'package:loggym/ui/core/brand_colors.dart';
import 'package:loggym/ui/core/wordmark.dart';
import 'package:loggym/ui/session/start_workout.dart';
import 'package:loggym/ui/subscriptions/subscription_card.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _focusedDay = ref.read(selectedDayProvider);
  var _showingYear = false;
  late int _year = _focusedDay.year;

  DateTime get _focusedMonth => DateTime(_focusedDay.year, _focusedDay.month);

  Future<({int? planId})?> _chooseStart() async {
    final plans = await ref.read(planRepositoryProvider).loadPlans();
    if (!mounted) return null;
    return chooseWorkoutStart(context, plans);
  }

  Future<void> _startWorkout() async {
    final choice = await _chooseStart();
    if (choice == null || !mounted) return;
    await startWorkout(context, ref, planId: choice.planId);
  }

  Future<void> _logPastWorkout(DateTime day) async {
    final choice = await _chooseStart();
    if (choice == null) return;
    final id = await ref
        .read(workoutSessionRepositoryProvider)
        .logPastSession(day, planId: choice.planId);
    if (mounted) {
      await context.push(
        Routes.session(id, pickExercises: choice.planId == null),
      );
    }
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    ref.listen(
      selectedDayProvider,
      (_, day) => setState(() => _focusedDay = day),
    );

    return Scaffold(
      appBar: AppBar(title: const Wordmark()),
      floatingActionButton: switch (selectedDay.compareTo(today)) {
        _ when _showingYear => null,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.calendar_view_month),
                  label: Text('Month'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.insights),
                  label: Text('Year'),
                ),
              ],
              selected: {_showingYear},
              onSelectionChanged: (selection) => setState(() {
                _showingYear = selection.single;
                _year = _focusedDay.year;
              }),
            ),
          ),
          if (_showingYear)
            YearView(
              year: _year,
              onYearChanged: (year) => setState(() => _year = year),
              onMonthSelected: (month) => setState(() {
                _focusedDay = month;
                _showingYear = false;
              }),
            )
          else ...[
            TableCalendar<SessionOverview>(
              firstDay: DateTime(2000),
              lastDay: DateTime(2100),
              focusedDay: _focusedDay,
              startingDayOfWeek: StartingDayOfWeek.monday,
              availableCalendarFormats: const {CalendarFormat.month: 'Month'},
              calendarStyle: _calendarStyle(Theme.of(context)),
              headerStyle: HeaderStyle(
                titleTextStyle: Theme.of(context).textTheme.titleLarge!,
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: Theme.of(context).textTheme.labelMedium!.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                weekendStyle: Theme.of(context).textTheme.labelMedium!.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
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
            const SubscriptionSection(),
          ],
        ],
      ),
    );
  }
}

/// Selected day filled, today outlined, workout dots in coral.
CalendarStyle _calendarStyle(ThemeData theme) {
  final colors = theme.colorScheme;
  final day = theme.textTheme.bodyLarge!.copyWith(color: colors.onSurface);
  return CalendarStyle(
    markersMaxCount: 3,
    markerDecoration: const BoxDecoration(
      color: BrandColors.coral,
      shape: BoxShape.circle,
    ),
    defaultTextStyle: day,
    weekendTextStyle: day,
    outsideTextStyle: day.copyWith(color: colors.outline),
    selectedDecoration: BoxDecoration(
      color: colors.primary,
      shape: BoxShape.circle,
    ),
    selectedTextStyle: day.copyWith(
      color: colors.onPrimary,
      fontWeight: FontWeight.w600,
    ),
    todayDecoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: colors.primary, width: 1.5),
    ),
    todayTextStyle: day.copyWith(
      color: colors.primary,
      fontWeight: FontWeight.w600,
    ),
  );
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
