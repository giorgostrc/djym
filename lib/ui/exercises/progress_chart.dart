import 'dart:math';

import 'package:djym/data/repositories/exercise_history_repository.dart';
import 'package:djym/domain/unit_system.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _chartHeight = 200.0;

enum ProgressRange {
  threeMonths('3M', 91),
  year('1Y', 365),
  all('All', null)
  ;

  const ProgressRange(this.label, this.days);

  final String label;
  final int? days;
}

extension ProgressMetricDisplay on ProgressMetric {
  String get label => switch (this) {
    ProgressMetric.heaviestWeight => 'Heaviest weight',
    ProgressMetric.estimatedOneRepMax => 'Est. 1RM',
    ProgressMetric.mostReps => 'Most reps',
    ProgressMetric.longestDuration => 'Longest time',
    ProgressMetric.longestDistance => 'Longest distance',
  };

  /// [value] in kg, reps, seconds or metres, as stored.
  String format(double value, UnitSystem units) =>
      '${formatChartValue(chartValue(value, units), units)}${_unit(units)}';

  double chartValue(double value, UnitSystem units) => switch (this) {
    ProgressMetric.heaviestWeight ||
    ProgressMetric.estimatedOneRepMax => units.weightFromKg(value),
    ProgressMetric.longestDistance => units.distanceFromMetres(value),
    ProgressMetric.mostReps || ProgressMetric.longestDuration => value,
  };

  String formatChartValue(double value, UnitSystem units) => switch (this) {
    ProgressMetric.heaviestWeight ||
    ProgressMetric.estimatedOneRepMax => formatNumber(value),
    ProgressMetric.longestDistance => formatNumber(value, decimals: 2),
    ProgressMetric.mostReps => '${value.round()}',
    ProgressMetric.longestDuration => formatDuration(value.round()),
  };

  String _unit(UnitSystem units) => switch (this) {
    ProgressMetric.heaviestWeight ||
    ProgressMetric.estimatedOneRepMax => ' ${units.weightUnit}',
    ProgressMetric.longestDistance => ' ${units.distanceUnit}',
    ProgressMetric.mostReps => ' reps',
    ProgressMetric.longestDuration => '',
  };
}

/// The best value of [metric] in each workout of [range], oldest first.
List<({DateTime date, double value})> progressPoints(
  ExerciseHistory history,
  ProgressMetric metric,
  ProgressRange range, {
  required DateTime now,
}) {
  final days = range.days;
  final since = days == null ? null : now.subtract(Duration(days: days));
  return [
    for (final workout in history.workouts.reversed)
      if (since == null || workout.session.startedAt.isAfter(since))
        if (metric.bestIn(workout.sets) case final value?)
          (date: workout.session.startedAt, value: value),
  ];
}

class ProgressChart extends StatelessWidget {
  const ProgressChart({
    required this.points,
    required this.metric,
    required this.units,
    required this.emptyMessage,
    super.key,
  });

  final List<({DateTime date, double value})> points;
  final ProgressMetric metric;
  final UnitSystem units;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    if (points.length < 2) {
      return SizedBox(
        height: _chartHeight,
        child: Center(
          child: Text(
            emptyMessage,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ),
      );
    }

    final values = [
      for (final point in points) metric.chartValue(point.value, units),
    ];
    final lowest = values.reduce(min);
    final highest = values.reduce(max);
    final padding = highest == lowest
        ? max(1, highest * 0.1)
        : (highest - lowest) * 0.15;
    // Days since the first point, so axis labels start at its date.
    final firstDate = points.first.date;
    double dayOf(DateTime date) =>
        date.difference(firstDate).inMinutes / Duration.minutesPerDay;
    DateTime dateOf(double day) => firstDate.add(
      Duration(minutes: (day * Duration.minutesPerDay).round()),
    );
    final span = dayOf(points.last.date);
    final dateFormat = span < 180 ? DateFormat.MMMd() : DateFormat.yMMM();
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: colors.onSurfaceVariant,
    );

    return SizedBox(
      height: _chartHeight,
      child: LineChart(
        LineChartData(
          minY: max(0, lowest - padding),
          maxY: highest + padding,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: colors.outlineVariant, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                minIncluded: false,
                maxIncluded: false,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(
                    metric.formatChartValue(value, units),
                    style: labelStyle,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: max(1, span / 2),
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  meta: meta,
                  fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                  child: Text(
                    dateFormat.format(dateOf(value)),
                    style: labelStyle,
                  ),
                ),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipColor: (_) => colors.inverseSurface,
              getTooltipItems: (spots) => [
                for (final spot in spots)
                  LineTooltipItem(
                    '${metric.format(points[spot.spotIndex].value, units)}\n',
                    theme.textTheme.labelLarge!.copyWith(
                      color: colors.onInverseSurface,
                    ),
                    children: [
                      TextSpan(
                        text: DateFormat.yMMMd().format(
                          points[spot.spotIndex].date,
                        ),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onInverseSurface,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (final (index, point) in points.indexed)
                  FlSpot(dayOf(point.date), values[index]),
              ],
              isCurved: true,
              preventCurveOverShooting: true,
              color: colors.primary,
              barWidth: points.length <= 30 ? 3 : 2,
              dotData: FlDotData(show: points.length <= 30),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colors.primary.withValues(alpha: 0.25),
                    colors.primary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
