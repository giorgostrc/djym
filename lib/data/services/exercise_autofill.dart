import 'package:djym/data/services/ai_client.dart';
import 'package:djym/domain/tracking_type.dart';

const _instructions = '''
You fill in exercise entries for a gym logging app. Given an exercise name:
- title: its common English name in sentence case with typos fixed, e.g. "Bulgarian split squat". Keep the name as typed when it is already right.
- trackingType: weightReps for loaded lifts logged as weight and reps; reps for bodyweight moves logged as reps only; duration for holds and timed work such as a plank; distanceDuration for cardio logged as distance and time such as running or rowing.
- muscles: the muscles it works, most involved first, at most 4.
- formCues: 3 to 5 short imperative form cues, each under 90 characters, without numbering.
- recognized: false when the name is not a recognisable exercise.''';

class ExerciseDraft {
  const ExerciseDraft({
    required this.title,
    required this.trackingType,
    required this.muscleNames,
    required this.formGuidance,
  });

  final String title;
  final TrackingType trackingType;

  /// Most involved first, all from the muscles the app knows.
  final List<String> muscleNames;
  final String formGuidance;
}

Future<ExerciseDraft> draftExercise(
  AiClient client, {
  required String title,
  required List<String> muscleNames,
}) async {
  final json = await client.generateJson(
    instructions: _instructions,
    prompt: 'Exercise name: $title',
    schema: {
      'type': 'object',
      'properties': {
        'recognized': {'type': 'boolean'},
        'title': {'type': 'string'},
        'trackingType': {
          'type': 'string',
          'enum': [for (final type in TrackingType.values) type.name],
        },
        'muscles': {
          'type': 'array',
          'items': {'type': 'string', 'enum': muscleNames},
        },
        'formCues': {
          'type': 'array',
          'items': {'type': 'string'},
        },
      },
      'required': [
        'recognized',
        'title',
        'trackingType',
        'muscles',
        'formCues',
      ],
      'additionalProperties': false,
    },
  );
  if (json['recognized'] != true) {
    throw AiException('"$title" was not recognised as an exercise');
  }

  return ExerciseDraft(
    title: json['title'] as String,
    trackingType: TrackingType.values.byName(json['trackingType'] as String),
    muscleNames: {
      for (final name in (json['muscles'] as List).cast<String>())
        if (muscleNames.contains(name)) name,
    }.take(4).toList(),
    formGuidance: (json['formCues'] as List).cast<String>().join('\n'),
  );
}
