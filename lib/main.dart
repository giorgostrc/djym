import 'dart:async';
import 'dart:ui';

import 'package:djym/app.dart';
import 'package:djym/data/services/error_log.dart';
import 'package:djym/data/services/rest_alerts.dart';
import 'package:djym/routing/router.dart';
import 'package:djym/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();

  final errorLog = await container.read(errorLogProvider.future);
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    errorLog.record(details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    errorLog.record(error, stack);
    return false;
  };

  await container.read(restAlertsProvider).initialize((sessionId) {
    final router = container.read(routerProvider);
    final location = Routes.session(sessionId);
    if (router.state.uri.path != location) unawaited(router.push(location));
  });
  runApp(
    UncontrolledProviderScope(container: container, child: const DjymApp()),
  );
}
