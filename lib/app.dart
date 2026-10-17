import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loggym/data/repositories/settings_repository.dart';
import 'package:loggym/data/repositories/workout_session_repository.dart';
import 'package:loggym/domain/theme_preference.dart';
import 'package:loggym/routing/router.dart';
import 'package:loggym/ui/core/app_theme.dart';
import 'package:loggym/ui/core/keep_screen_on.dart';

class LogGymApp extends ConsumerWidget {
  const LogGymApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(
      activeSessionProvider.select((session) => session.value != null),
      (_, active) => ref.read(keepScreenOnProvider)(on: active),
    );
    final themePreference =
        ref.watch(settingsProvider).value?.themePreference ??
        ThemePreference.system;

    return MaterialApp.router(
      title: 'LogGym',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: AppTheme.modeFor(themePreference),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
