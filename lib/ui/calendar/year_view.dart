import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:loggym/data/repositories/settings_repository.dart';
import 'package:loggym/data/repositories/stats_repository.dart';
import 'package:loggym/domain/money.dart';
import 'package:loggym/domain/subscription_period.dart';
import 'package:loggym/domain/unit_system.dart';
import 'package:loggym/ui/core/brand_colors.dart';
import 'package:loggym/ui/exercises/exercise_avatar.dart';

/// A year at a glance: headline numbers, a heatmap of training days per
/// month, and the exercises done most often.
class YearView extends ConsumerWidget {
  const YearView({
    required this.year,
    required this.onYearChanged,
    required this.onMonthSelected,
    super.key,
  });

  final int year;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<DateTime> onMonthSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(yearStatsProvider(year)).value;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _YearStepper(
          year: year,
          onChanged: onYearChanged,
          canGoForward: year < DateTime.now().year,
        ),
        if (stats == null)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          if (stats.workoutCount == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                'No workouts in $year',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          else
            _Headline(stats: stats),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _MonthGrid(
              year: year,
              workoutsPerDay: stats.workoutsPerDay,
              onMonthSelected: onMonthSelected,
            ),
          ),
          const _Legend(),
          if (stats.topExercises.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
              child: Text('Most trained', style: theme.textTheme.titleMedium),
            ),
            for (final frequency in stats.topExercises)
              _ExerciseFrequencyTile(
                frequency: frequency,
                mostWorkouts: stats.topExercises.first.workoutCount,
              ),
          ],
        ],
      ],
    );
  }
}

class _YearStepper extends StatelessWidget {
  const _YearStepper({
    required this.year,
    required this.onChanged,
    required this.canGoForward,
  });

  final int year;
  final ValueChanged<int> onChanged;
  final bool canGoForward;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Previous year',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(year - 1),
        ),
        SizedBox(
          width: 88,
          child: Text(
            '$year',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        IconButton(
          tooltip: 'Next year',
          icon: const Icon(Icons.chevron_right),
          onPressed: canGoForward ? () => onChanged(year + 1) : null,
        ),
      ],
    );
  }
}

class _Headline extends ConsumerWidget {
  const _Headline({required this.stats});

  final YearStats stats;

  static String _hours(Duration duration) {
    final hours = duration.inMinutes / 60;
    return hours < 1
        ? '${duration.inMinutes} min'
        : '${formatNumber(hours, decimals: hours < 10 ? 1 : 0)} h';
  }

  static String _weeks(int weeks) => weeks == 1 ? '1 week' : '$weeks weeks';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    final units = settings?.unitSystem ?? UnitSystem.metric;
    final currency = settings?.currencyCode ?? 'EUR';
    final volume = units.weightFromKg(stats.volumeKg);
    final costPerWorkout = stats.costPerWorkoutCents;
    final count = NumberFormat.decimalPattern();

    final tiles = [
      (count.format(stats.workoutCount), 'workouts'),
      (_hours(stats.timeTrained), 'trained'),
      (count.format(stats.setCount), 'sets'),
      (
        volume == 0
            ? '—'
            : '${NumberFormat.compact().format(volume)} ${units.weightUnit}',
        'lifted',
      ),
      ('${stats.activeWeeks}', 'active weeks'),
      (_weeks(stats.longestStreakWeeks), 'best streak'),
      if (stats.subscriptionSpendCents > 0) ...[
        (formatMoney(stats.subscriptionSpendCents, currency), 'subscriptions'),
        (
          costPerWorkout == null ? '—' : formatMoney(costPerWorkout, currency),
          'per workout',
        ),
      ],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 8.0;
          final columns = constraints.maxWidth > 600 ? 4 : 2;
          final width =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final (value, label) in tiles)
                SizedBox(
                  width: width,
                  child: _StatTile(value: value, label: label),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: theme.textTheme.titleLarge),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Turquoise for one workout, the stronger brand colour for more.
Color _dayColor(ColorScheme colors, int workouts) {
  final dark = colors.brightness == Brightness.dark;
  return switch (workouts) {
    0 when dark => colors.surfaceContainer,
    0 => colors.surfaceContainerHighest,
    1 when dark => colors.primary.withValues(alpha: 0.55),
    1 => BrandColors.turquoise,
    _ => colors.primary,
  };
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.year,
    required this.workoutsPerDay,
    required this.onMonthSelected,
  });

  final int year;
  final Map<DateTime, int> workoutsPerDay;
  final ValueChanged<DateTime> onMonthSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final columns = constraints.maxWidth > 600 ? 4 : 3;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var month = 1; month <= 12; month++)
              SizedBox(
                width: width,
                child: _MiniMonth(
                  month: DateTime(year, month),
                  workoutsPerDay: workoutsPerDay,
                  onTap: () => onMonthSelected(DateTime(year, month)),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MiniMonth extends StatelessWidget {
  const _MiniMonth({
    required this.month,
    required this.workoutsPerDay,
    required this.onTap,
  });

  final DateTime month;
  final Map<DateTime, int> workoutsPerDay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final today = dateOnly(DateTime.now());
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = month.weekday - 1;
    final total = [
      for (var day = 1; day <= daysInMonth; day++)
        workoutsPerDay[DateTime(month.year, month.month, day)] ?? 0,
    ].fold(0, (a, b) => a + b);
    final name = DateFormat.MMMM().format(month);

    final cells = <Widget>[
      for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
      for (var day = 1; day <= daysInMonth; day++)
        _DayCell(
          day: DateTime(month.year, month.month, day),
          workouts: workoutsPerDay[DateTime(month.year, month.month, day)] ?? 0,
          today: today,
        ),
    ];

    return Semantics(
      button: true,
      label: '$name, ${total == 1 ? '1 workout' : '$total workouts'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 6,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat.MMM().format(month),
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  if (total > 0)
                    Text(
                      '$total',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.primary,
                      ),
                    ),
                ],
              ),
              GridView.count(
                crossAxisCount: 7,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: cells,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.workouts,
    required this.today,
  });

  final DateTime day;
  final int workouts;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final future = day.isAfter(today);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: future
            ? colors.surfaceContainerHighest.withValues(alpha: 0.4)
            : _dayColor(colors, workouts),
        borderRadius: BorderRadius.circular(2),
        border: day == today
            ? Border.all(color: colors.onSurface, width: 1.5)
            : null,
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final style = theme.textTheme.labelSmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    Widget swatch(int workouts) => Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: _dayColor(colors, workouts),
        borderRadius: BorderRadius.circular(2),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        spacing: 6,
        children: [
          swatch(0),
          Text('None', style: style),
          const SizedBox(width: 4),
          swatch(1),
          Text('1 workout', style: style),
          const SizedBox(width: 4),
          swatch(2),
          Text('2+', style: style),
        ],
      ),
    );
  }
}

class _ExerciseFrequencyTile extends StatelessWidget {
  const _ExerciseFrequencyTile({
    required this.frequency,
    required this.mostWorkouts,
  });

  final ExerciseFrequency frequency;
  final int mostWorkouts;

  @override
  Widget build(BuildContext context) {
    final count = frequency.workoutCount;
    return ListTile(
      leading: ExerciseAvatar(frequency.exercise),
      title: Text(frequency.exercise.title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: LinearProgressIndicator(
          value: count / mostWorkouts,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      trailing: Text(count == 1 ? '1 workout' : '$count workouts'),
    );
  }
}
