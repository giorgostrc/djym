import 'dart:async';

import 'package:djym/data/database/app_database.dart';
import 'package:djym/data/repositories/exercise_repository.dart';
import 'package:djym/data/services/ai_client.dart';
import 'package:djym/data/services/exercise_autofill.dart';
import 'package:djym/data/services/wger_client.dart';
import 'package:djym/domain/tracking_type.dart';
import 'package:djym/ui/core/text_input.dart';
import 'package:djym/ui/exercises/ai_fill_tile.dart';
import 'package:djym/ui/exercises/remove_exercise.dart';
import 'package:djym/ui/exercises/tracking_type_display.dart';
import 'package:djym/ui/exercises/wger_suggestions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

final imagePickerProvider = Provider<ImagePicker>((ref) => ImagePicker());

enum _PhotoChoice { gallery, camera, remove }

class ExerciseFormScreen extends ConsumerWidget {
  const ExerciseFormScreen({this.exerciseId, this.initialTitle, super.key});

  final int? exerciseId;
  final String? initialTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (exerciseId == null) return _ExerciseForm(initialTitle: initialTitle);

    final existing = ref
        .watch(exercisesProvider)
        .value
        ?.where((entry) => entry.exercise.id == exerciseId)
        .firstOrNull;
    if (existing == null) return const Scaffold();

    return _ExerciseForm(existing: existing);
  }
}

class _ExerciseForm extends ConsumerStatefulWidget {
  const _ExerciseForm({this.existing, this.initialTitle});

  final ExerciseWithMuscles? existing;
  final String? initialTitle;

  @override
  ConsumerState<_ExerciseForm> createState() => _ExerciseFormState();
}

class _ExerciseFormState extends ConsumerState<_ExerciseForm> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(
    text: widget.existing?.exercise.title ?? widget.initialTitle,
  );
  late final _formGuidance = TextEditingController(
    text: widget.existing?.exercise.formGuidance,
  );
  late TrackingType _trackingType =
      widget.existing?.exercise.trackingType ?? TrackingType.weightReps;
  late final List<int> _muscleIds = [
    for (final muscle in widget.existing?.muscles ?? <Muscle>[]) muscle.id,
  ];
  var _dirty = false;

  late String _suggestionTerm = (widget.initialTitle ?? '').trim();
  Timer? _suggestionDebounce;
  WgerExercise? _prefill;
  var _aiFilled = false;
  var _aiFilling = false;
  late ({
    String title,
    TrackingType trackingType,
    String guidance,
    List<int> muscleIds,
    Future<Uint8List?> thumbnail,
  })
  _beforePrefill;

  /// The photo as it will be saved; a future because existing photos and
  /// wger downloads arrive asynchronously.
  late Future<Uint8List?> _thumbnail = switch (widget.existing) {
    final existing? =>
      ref.read(exerciseRepositoryProvider).thumbnail(existing.exercise.id),
    null => Future.value(),
  };

  bool get _suggestsFromWger =>
      widget.existing == null && _prefill == null && !_aiFilled;

  @override
  void dispose() {
    _suggestionDebounce?.cancel();
    _title.dispose();
    _formGuidance.dispose();
    super.dispose();
  }

  void _markDirty() => setState(() => _dirty = true);

  void _onTitleChanged(String title) {
    _markDirty();
    if (!_suggestsFromWger) return;

    _suggestionDebounce?.cancel();
    _suggestionDebounce = Timer(
      const Duration(milliseconds: 400),
      () => setState(() => _suggestionTerm = title.trim()),
    );
  }

  List<Muscle> get _muscles => ref.read(musclesProvider).value ?? [];

  void _fillForm({
    required String title,
    required String guidance,
    required List<String> muscleNames,
    TrackingType? trackingType,
  }) {
    final idByName = {for (final muscle in _muscles) muscle.name: muscle.id};
    _beforePrefill = (
      title: _title.text,
      trackingType: _trackingType,
      guidance: _formGuidance.text,
      muscleIds: [..._muscleIds],
      thumbnail: _thumbnail,
    );
    _title.text = title;
    _trackingType = trackingType ?? _trackingType;
    _formGuidance.text = guidance;
    _muscleIds
      ..clear()
      ..addAll([for (final name in muscleNames) idByName[name]!]);
    FocusScope.of(context).unfocus();
    _markDirty();
  }

  void _applyPrefill(WgerExercise source) {
    _fillForm(
      title: source.name,
      guidance: source.description ?? '',
      muscleNames: source.muscleNames,
    );
    _prefill = source;
    _thumbnail = _downloadThumbnail(source);
  }

  Future<void> _fillWithAi(AiClient client) async {
    setState(() => _aiFilling = true);
    try {
      final draft = await draftExercise(
        client,
        title: _title.text.trim(),
        muscleNames: [for (final muscle in _muscles) muscle.name],
      );
      if (!mounted) return;
      _fillForm(
        title: draft.title,
        trackingType: draft.trackingType,
        guidance: draft.formGuidance,
        muscleNames: draft.muscleNames,
      );
      _aiFilled = true;
    } on AiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _aiFilling = false);
    }
  }

  void _clearPrefill() {
    final before = _beforePrefill;
    _prefill = null;
    _aiFilled = false;
    _thumbnail = before.thumbnail;
    _trackingType = before.trackingType;
    _title.text = before.title;
    _formGuidance.text = before.guidance;
    _muscleIds
      ..clear()
      ..addAll(before.muscleIds);
    _suggestionTerm = before.title.trim();
    _markDirty();
  }

  Future<void> _changePhoto() async {
    final hasPhoto = await _thumbnail != null;
    if (!mounted) return;

    final choice = await showModalBottomSheet<_PhotoChoice>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, _PhotoChoice.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(context, _PhotoChoice.camera),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove photo'),
                onTap: () => Navigator.pop(context, _PhotoChoice.remove),
              ),
          ],
        ),
      ),
    );

    switch (choice) {
      case null:
        return;
      case _PhotoChoice.remove:
        _thumbnail = Future.value();
      case _PhotoChoice.gallery || _PhotoChoice.camera:
        final XFile? picked;
        try {
          picked = await ref
              .read(imagePickerProvider)
              .pickImage(
                source: choice == _PhotoChoice.camera
                    ? ImageSource.camera
                    : ImageSource.gallery,
                maxWidth: 256,
                maxHeight: 256,
                imageQuality: 80,
              );
        } on PlatformException {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open the photo picker')),
          );
          return;
        }
        if (picked == null || !mounted) return;
        _thumbnail = picked.readAsBytes();
    }
    _markDirty();
  }

  /// A missing thumbnail must never block saving the exercise.
  Future<Uint8List?> _downloadThumbnail(WgerExercise source) async {
    final url = source.thumbnailUrl;
    if (url == null) return null;
    try {
      return await ref.read(wgerClientProvider).download(url);
    } on Exception {
      return null;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final guidance = _formGuidance.text.trim();
    final thumbnail = await _thumbnail;
    final id = await ref
        .read(exerciseRepositoryProvider)
        .saveExercise(
          id: widget.existing?.exercise.id,
          title: _title.text.trim(),
          trackingType: _trackingType,
          formGuidance: guidance.isEmpty ? null : guidance,
          muscleIds: _muscleIds,
          externalId: _prefill?.externalId,
          thumbnail: thumbnail,
        );
    if (mounted) context.pop(id);
  }

  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(exerciseRepositoryProvider);
    context.pop();
    await removeExerciseWithUndo(
      messenger: messenger,
      repository: repository,
      entry: widget.existing!,
    );
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if ((discard ?? false) && mounted) context.pop();
  }

  void _toggleMuscle(int muscleId) {
    _muscleIds.contains(muscleId)
        ? _muscleIds.remove(muscleId)
        : _muscleIds.add(muscleId);
    _markDirty();
  }

  @override
  Widget build(BuildContext context) {
    final muscles = ref.watch(musclesProvider).value ?? const [];
    final aiClient = ref.watch(aiClientProvider);
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.existing == null ? 'New exercise' : 'Edit exercise',
          ),
          actions: [
            if (widget.existing != null)
              IconButton(
                tooltip: 'Delete exercise',
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete,
              ),
            TextButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _PhotoField(thumbnail: _thumbnail, onTap: _changePhoto),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                autofocus: widget.existing == null,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Title',
                  counterText: '',
                  suffixIcon: clearButton(_title, onChanged: _onTitleChanged),
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Give the exercise a title'
                    : null,
                onChanged: _onTitleChanged,
              ),
              if (_prefill case final prefill?)
                PrefillCard(
                  leading: WgerThumbnail(prefill.thumbnailUrl),
                  title: 'Prefilled from wger',
                  subtitle: prefill.name,
                  onClear: _clearPrefill,
                )
              else if (_aiFilled)
                PrefillCard(
                  leading: const Icon(Icons.auto_awesome),
                  title: 'Filled with AI',
                  subtitle: 'Check the details before saving',
                  onClear: _clearPrefill,
                )
              else if (_suggestsFromWger) ...[
                if (aiClient != null &&
                    _title.text.trim().length >= minimumSuggestionTermLength)
                  AiFillTile(
                    title: _title.text.trim(),
                    filling: _aiFilling,
                    onTap: () => _fillWithAi(aiClient),
                  ),
                WgerSuggestions(
                  term: _suggestionTerm,
                  onSelected: _applyPrefill,
                ),
              ],
              const SizedBox(height: 24),
              Text('Tracking', style: textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in TrackingType.values)
                    ChoiceChip(
                      avatar: Icon(type.icon),
                      label: Text(type.label),
                      selected: type == _trackingType,
                      showCheckmark: false,
                      onSelected: (_) {
                        _trackingType = type;
                        _markDirty();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Muscles', style: textTheme.titleSmall),
              Text(
                'Tap in order of involvement. The first is the main muscle.',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final muscle in muscles)
                    FilterChip(
                      avatar: _muscleIds.contains(muscle.id)
                          ? CircleAvatar(
                              child: Text(
                                '${_muscleIds.indexOf(muscle.id) + 1}',
                              ),
                            )
                          : null,
                      label: Text(muscle.name),
                      selected: _muscleIds.contains(muscle.id),
                      showCheckmark: false,
                      onSelected: (_) => _toggleMuscle(muscle.id),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _formGuidance,
                minLines: 3,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Form guidance (optional)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _markDirty(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoField extends StatelessWidget {
  const _PhotoField({required this.thumbnail, required this.onTap});

  final Future<Uint8List?> thumbnail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const size = 96.0;

    return Center(
      child: Tooltip(
        message: 'Change photo',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox.square(
                  dimension: size,
                  child: ColoredBox(
                    color: colors.surfaceContainerHighest,
                    child: FutureBuilder(
                      future: thumbnail,
                      builder: (context, snapshot) {
                        final image = snapshot.data;
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final placeholder = Icon(
                          Icons.add_a_photo_outlined,
                          color: colors.onSurfaceVariant,
                        );
                        if (image == null) return placeholder;
                        return Image.memory(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => placeholder,
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 4,
                bottom: 4,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: colors.primary,
                  child: Icon(Icons.edit, size: 16, color: colors.onPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
