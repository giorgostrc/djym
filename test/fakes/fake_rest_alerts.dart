import 'package:loggym/data/services/rest_alerts.dart';
import 'package:loggym/domain/rest.dart';

class FakeRestAlerts implements RestAlerts {
  FakeRestAlerts({this.notificationsEnabled = true});

  bool notificationsEnabled;
  int permissionRequests = 0;
  final scheduled = <Rest>[];
  bool cancelled = false;

  @override
  Future<void> initialize(void Function(int sessionId) onOpen) async {}

  @override
  Future<bool> enabled() async => notificationsEnabled;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return notificationsEnabled = true;
  }

  @override
  Future<void> schedule(Rest rest, {required int sessionId}) async {
    cancelled = false;
    scheduled.add(rest);
  }

  @override
  Future<void> cancel() async => cancelled = true;
}
