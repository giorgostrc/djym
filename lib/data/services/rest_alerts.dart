import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loggym/domain/rest.dart';
import 'package:timezone/timezone.dart' as tz;

const _countdownId = 1;
const _restOverId = 2;
const _icon = 'ic_rest_timer';

/// A live countdown in the notification shade while resting, and an alert
/// when the rest is over that also fires with the phone locked.
class RestAlerts {
  final _plugin = FlutterLocalNotificationsPlugin();

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// [onOpen] receives the workout of a tapped notification, including the
  /// one that launched the app.
  Future<void> initialize(void Function(int sessionId) onOpen) async {
    void open(String? payload) {
      final sessionId = int.tryParse(payload ?? '');
      if (sessionId != null) onOpen(sessionId);
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_icon),
      ),
      onDidReceiveNotificationResponse: (response) => open(response.payload),
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (!(launch?.didNotificationLaunchApp ?? false)) return;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => open(launch!.notificationResponse?.payload),
    );
  }

  Future<bool> enabled() async =>
      await _android?.areNotificationsEnabled() ?? false;

  Future<bool> requestPermission() async =>
      await _android?.requestNotificationsPermission() ?? false;

  Future<void> schedule(Rest rest, {required int sessionId}) async {
    await cancel();
    final android = _android;
    if (android == null || !await enabled()) return;

    final exact = await android.canScheduleExactNotifications() ?? false;
    await _plugin.show(
      id: _countdownId,
      title: 'Resting',
      body: 'Tap to return to your workout',
      payload: '$sessionId',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'rest_countdown',
          'Rest countdown',
          channelDescription: 'Time left while resting between sets',
          importance: Importance.low,
          priority: Priority.low,
          silent: true,
          when: rest.endsAt.millisecondsSinceEpoch,
          usesChronometer: true,
          chronometerCountDown: true,
          timeoutAfter: rest.remainingAt(DateTime.now()).inMilliseconds,
        ),
      ),
    );
    await _plugin.zonedSchedule(
      id: _restOverId,
      title: 'Rest is over',
      body: 'Time for your next set',
      payload: '$sessionId',
      scheduledDate: tz.TZDateTime.from(rest.endsAt, tz.UTC),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'rest_over',
          'Rest over',
          channelDescription: 'Alerts you when it is time for the next set',
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
        ),
      ),
    );
  }

  Future<void> cancel() => _plugin.cancelAll();
}

final restAlertsProvider = Provider<RestAlerts>((ref) => RestAlerts());
