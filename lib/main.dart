import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loggym/app.dart';
import 'package:loggym/data/services/rest_alerts.dart';
import 'package:loggym/routing/router.dart';
import 'package:loggym/routing/routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  await container.read(restAlertsProvider).initialize((sessionId) {
    final router = container.read(routerProvider);
    final location = Routes.session(sessionId);
    if (router.state.uri.path != location) unawaited(router.push(location));
  });
  runApp(
    UncontrolledProviderScope(container: container, child: const DjymApp()),
  );
}
