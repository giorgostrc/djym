import 'package:djym/domain/tracking_type.dart';
import 'package:flutter/material.dart';

extension TrackingTypeDisplay on TrackingType {
  String get label => switch (this) {
    TrackingType.weightReps => 'Weight × reps',
    TrackingType.reps => 'Reps',
    TrackingType.duration => 'Time',
    TrackingType.distanceDuration => 'Distance + time',
  };

  IconData get icon => switch (this) {
    TrackingType.weightReps => Icons.fitness_center,
    TrackingType.reps => Icons.repeat,
    TrackingType.duration => Icons.timer_outlined,
    TrackingType.distanceDuration => Icons.directions_run,
  };
}
