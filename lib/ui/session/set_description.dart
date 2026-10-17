import 'package:loggym/data/database/app_database.dart';
import 'package:loggym/domain/tracking_type.dart';
import 'package:loggym/domain/unit_system.dart';

/// A one-line summary such as `60 kg × 8`, `1:30` or `5 km in 25:00`.
String describeSet(ExerciseSet set, TrackingType type, UnitSystem units) {
  final weight = set.weightKg;
  final distance = set.distanceMeters;
  final duration = set.durationSeconds;
  final weightText = weight == null
      ? null
      : '${formatNumber(units.weightFromKg(weight))} ${units.weightUnit}';
  final distanceText = distance == null
      ? null
      : '${formatNumber(units.distanceFromMetres(distance), decimals: 2)} '
            '${units.distanceUnit}';
  final durationText = duration == null ? null : formatDuration(duration);

  return switch (type) {
    TrackingType.weightReps => [?weightText, ?set.reps?.toString()].join(' × '),
    TrackingType.reps => '${set.reps ?? 0} reps',
    TrackingType.duration => durationText ?? '',
    TrackingType.distanceDuration => [
      ?distanceText,
      ?durationText,
    ].join(' in '),
  };
}
