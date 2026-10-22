import 'dart:ui' as ui;

import 'package:djym/data/database/app_database.dart';
import 'package:djym/data/repositories/workout_session_repository.dart';
import 'package:djym/domain/unit_system.dart';
import 'package:djym/ui/core/brand_colors.dart';
import 'package:djym/ui/session/session_summary_sheet.dart';
import 'package:djym/ui/session/set_description.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

/// Laid out at phone width and exported at 1080 px, the width social apps
/// keep without resampling.
const _cardWidth = 360.0;
const _exportWidth = 1080.0;

Future<void> showWorkoutShare(
  BuildContext context, {
  required WorkoutSession session,
  required List<SessionExercise> exercises,
  required UnitSystem units,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _WorkoutShareSheet(
    card: WorkoutShareCard(
      session: session,
      exercises: exercises,
      units: units,
    ),
  ),
);

/// Previews the image exactly as it will be sent.
class _WorkoutShareSheet extends StatefulWidget {
  const _WorkoutShareSheet({required this.card});

  final WorkoutShareCard card;

  @override
  State<_WorkoutShareSheet> createState() => _WorkoutShareSheetState();
}

class _WorkoutShareSheetState extends State<_WorkoutShareSheet> {
  final GlobalKey _cardKey = GlobalKey();
  final GlobalKey _buttonKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary =
          _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(
        pixelRatio: _exportWidth / _cardWidth,
      );
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final button =
          _buttonKey.currentContext!.findRenderObject()! as RenderBox;

      final result = await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(png!.buffer.asUint8List(), mimeType: 'image/png'),
          ],
          fileNameOverrides: const ['djym-workout.png'],
          sharePositionOrigin: button.localToGlobal(Offset.zero) & button.size,
        ),
      );
      if (result.status == ShareResultStatus.success && mounted) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: RepaintBoundary(key: _cardKey, child: widget.card),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: FilledButton.icon(
              key: _buttonKey,
              onPressed: _sharing ? null : _share,
              icon: Icon(Icons.adaptive.share),
              label: const Text('Share image'),
            ),
          ),
        ),
      ],
    );
  }
}

/// A branded, theme-independent picture of a workout: headline numbers up
/// top, then every exercise with its sets.
class WorkoutShareCard extends StatelessWidget {
  const WorkoutShareCard({
    required this.session,
    required this.exercises,
    required this.units,
    super.key,
  });

  final WorkoutSession session;
  final List<SessionExercise> exercises;
  final UnitSystem units;

  static const _faint = Color(0x99F7FFF7);

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    String time(DateTime value) =>
        localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value));
    final finishedAt = session.finishedAt ?? session.startedAt;
    final stats = summaryStats(SessionSummary.of(session, exercises), units);
    final logged = [
      for (final entry in exercises)
        if (entry.sets.any((set) => set.hasValues)) entry,
    ];

    return MediaQuery.withNoTextScaling(
      child: Container(
        width: _cardWidth,
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [BrandColors.deepTeal, BrandColors.ink],
          ),
        ),
        child: DefaultTextStyle(
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            color: BrandColors.mint,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                spacing: 6,
                children: [
                  Image.asset('assets/brand/djinn.png', height: 24),
                  const Text(
                    'djym',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text.rich(
                TextSpan(
                  text: localizations.formatMediumDate(session.startedAt),
                  children: [
                    TextSpan(
                      text:
                          '\n${time(session.startedAt)} – ${time(finishedAt)}',
                      style: const TextStyle(color: _faint),
                    ),
                  ],
                ),
                style: const TextStyle(
                  fontSize: 26,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  runSpacing: 16,
                  children: [
                    for (final (label, value) in stats)
                      SizedBox(
                        width: constraints.maxWidth / 2,
                        child: _Stat(label: label, value: value),
                      ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Divider(height: 1, color: Color(0x26F7FFF7)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 18,
                children: [
                  for (final entry in logged)
                    _ExerciseSets(entry: entry, units: units),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            height: 1.1,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: BrandColors.turquoise,
          ),
        ),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: WorkoutShareCard._faint,
          ),
        ),
      ],
    );
  }
}

class _ExerciseSets extends StatelessWidget {
  const _ExerciseSets({required this.entry, required this.units});

  final SessionExercise entry;
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(
          entry.exercise.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final set in entry.sets.where((set) => set.hasValues))
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x14F7FFF7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: Text(
                    describeSet(set, entry.exercise.trackingType, units),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
