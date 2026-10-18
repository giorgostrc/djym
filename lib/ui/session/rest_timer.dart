import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loggym/data/repositories/settings_repository.dart';
import 'package:loggym/data/repositories/workout_session_repository.dart';
import 'package:loggym/data/services/rest_alerts.dart';
import 'package:loggym/domain/rest.dart';
import 'package:loggym/ui/core/clock_provider.dart';

class RestTimer extends Notifier<Rest?> {
  int? _sessionId;

  RestAlerts get _alerts => ref.read(restAlertsProvider);

  @override
  Rest? build() => null;

  Future<void> start(Duration length, {required int sessionId}) async {
    _sessionId = sessionId;
    state = Rest.startingAt(DateTime.now(), length);
    await _alerts.schedule(state!, sessionId: sessionId);
  }

  Future<void> adjust(Duration delta) async {
    final adjusted = state?.adjustedBy(delta);
    if (adjusted == null) return;
    if (adjusted.isOverAt(DateTime.now())) return skip();

    state = adjusted;
    await _alerts.schedule(adjusted, sessionId: _sessionId!);
  }

  Future<void> rescheduleAlerts() async {
    final rest = state;
    if (rest == null || rest.isOverAt(DateTime.now())) return;
    await _alerts.schedule(rest, sessionId: _sessionId!);
  }

  Future<void> skip() async {
    state = null;
    await _alerts.cancel();
  }

  Future<void> skipFor(int sessionId) async {
    if (sessionId == _sessionId) await skip();
  }
}

final restTimerProvider = NotifierProvider<RestTimer, Rest?>(RestTimer.new);

/// The rest still counting down. The clock only drives re-evaluation; time
/// is read fresh so a rest that just started never shows more than its length.
final runningRestProvider = Provider<Rest?>((ref) {
  final rest = ref.watch(restTimerProvider);
  if (rest == null) return null;
  ref.watch(clockProvider);
  return rest.isOverAt(DateTime.now()) ? null : rest;
});

/// Starts the default rest after a set in a running workout, and the first
/// time asks whether alerts may show while the phone is locked.
Future<void> startRestAfterSet(
  BuildContext context,
  WidgetRef ref,
  int sessionId,
) async {
  final session = ref.read(sessionProvider(sessionId)).value;
  final settings = ref.read(settingsProvider).value;
  if (session == null || session.finishedAt != null || settings == null) {
    return;
  }
  if (settings.restSeconds == 0) return;

  final timer = ref.read(restTimerProvider.notifier);
  final alerts = ref.read(restAlertsProvider);
  final settingsRepository = ref.read(settingsRepositoryProvider);
  await timer.start(
    Duration(seconds: settings.restSeconds),
    sessionId: sessionId,
  );
  if (settings.restAlertsPrompted) return;

  await settingsRepository.markRestAlertsPrompted();
  if (await alerts.enabled() || !context.mounted) return;

  final allow = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.notifications_active_outlined),
      title: const Text('Alert when rest is over?'),
      content: const Text(
        'djym can buzz you when it is time for the next set, '
        'even with the phone locked.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Not now'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Allow'),
        ),
      ],
    ),
  );
  if (!(allow ?? false)) return;
  if (await alerts.requestPermission()) await timer.rescheduleAlerts();
}
