import 'dart:io';

import 'package:djym/data/database/app_database.dart';
import 'package:djym/data/database/database_provider.dart';
import 'package:djym/data/repositories/settings_repository.dart';
import 'package:djym/data/services/backup_service.dart';
import 'package:djym/domain/subscription_period.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

String describeLastBackup(DateTime? at, DateTime now) {
  if (at == null) return 'Never backed up';
  return switch (daysBetween(at, now)) {
    0 => 'Last backup: today',
    1 => 'Last backup: yesterday',
    final days => 'Last backup: $days days ago',
  };
}

enum _BackupTask { export, import }

class BackupTiles extends ConsumerStatefulWidget {
  const BackupTiles({required this.lastBackupAt, super.key});

  final DateTime? lastBackupAt;

  @override
  ConsumerState<BackupTiles> createState() => _BackupTilesState();
}

class _BackupTilesState extends ConsumerState<BackupTiles> {
  _BackupTask? _running;

  Future<void> _export() async {
    setState(() => _running = _BackupTask.export);
    try {
      final service = await ref.read(backupServiceProvider.future);
      final backup = await service.export(
        ref.read(appDatabaseProvider),
        destination: service.workDirectory,
      );
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(backup.path, mimeType: 'application/octet-stream')],
          subject: 'djym backup',
        ),
      );
      if (result.status != ShareResultStatus.dismissed) {
        await ref.read(settingsRepositoryProvider).markBackedUp(DateTime.now());
      }
    } on Exception {
      if (mounted) {
        await _explain('Export failed', 'The backup could not be created.');
      }
    } finally {
      if (mounted) setState(() => _running = null);
    }
  }

  Future<void> _import() async {
    final path = (await FilePicker.pickFiles()).firstOrNull?.path;
    if (path == null || !mounted) return;

    final service = await ref.read(backupServiceProvider.future);
    final backup = File(path);
    final BackupInfo info;
    try {
      info = service.inspect(backup);
    } on FormatException {
      return _explain(
        'Not a djym backup',
        'Choose a .db file exported from djym.',
      );
    }
    if (info.schemaVersion > AppDatabase.currentSchemaVersion) {
      return _explain(
        'Backup from a newer app',
        'Update djym, then import this backup again.',
      );
    }
    if (!await _confirmReplace(info) || !mounted) return;

    setState(() => _running = _BackupTask.import);
    try {
      final database = ref.read(appDatabaseProvider);
      await service.export(database, destination: service.safetyDirectory);
      await service.restore(database, backup);
    } on Exception {
      if (mounted) {
        await _explain(
          'Import failed',
          'The backup could not be read. Your data was not changed.',
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _running = null);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Backup imported')));
  }

  Future<void> _explain(String title, String message) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  Future<bool> _confirmReplace(BackupInfo info) async {
    final lastWorkoutAt = info.lastWorkoutAt;
    final localizations = MaterialLocalizations.of(context);
    final contents = switch (info.workoutCount) {
      0 => 'The backup holds no workouts',
      1 => 'The backup holds 1 workout',
      final count => 'The backup holds $count workouts',
    };
    final latest = lastWorkoutAt == null
        ? ''
        : ', the latest on ${localizations.formatMediumDate(lastWorkoutAt)}';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace all data?'),
        content: Text(
          '$contents$latest.\n\nEverything on this phone will be replaced. '
          'A safety copy of your current data is saved first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    const progress = SizedBox.square(
      dimension: 24,
      child: CircularProgressIndicator(strokeWidth: 2),
    );

    return Column(
      children: [
        ListTile(
          enabled: _running == null,
          leading: const Icon(Icons.upload_file),
          title: const Text('Export backup'),
          subtitle: Text(
            describeLastBackup(widget.lastBackupAt, DateTime.now()),
          ),
          trailing: _running == _BackupTask.export ? progress : null,
          onTap: _export,
        ),
        ListTile(
          enabled: _running == null,
          leading: const Icon(Icons.download),
          title: const Text('Import backup'),
          subtitle: const Text('Replaces all data on this phone'),
          trailing: _running == _BackupTask.import ? progress : null,
          onTap: _import,
        ),
      ],
    );
  }
}
