import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loggym/routing/routes.dart';
import 'package:loggym/ui/calendar/calendar_screen.dart';
import 'package:loggym/ui/core/app_shell.dart';
import 'package:loggym/ui/exercises/exercise_form_screen.dart';
import 'package:loggym/ui/exercises/exercises_screen.dart';
import 'package:loggym/ui/plans/plans_screen.dart';
import 'package:loggym/ui/session/session_screen.dart';
import 'package:loggym/ui/settings/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: Routes.calendar,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.calendar,
                builder: (context, state) => const CalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.plans,
                builder: (context, state) => const PlansScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.exercises,
                builder: (context, state) => const ExercisesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.workoutSession,
        builder: (context, state) => SessionScreen(
          sessionId: int.parse(state.pathParameters['id']!),
          pickExercisesOnOpen: state.uri.queryParameters['pick'] == 'true',
        ),
      ),
      GoRoute(
        path: Routes.newExercise,
        pageBuilder: (context, state) => MaterialPage(
          fullscreenDialog: true,
          child: ExerciseFormScreen(
            initialTitle: state.uri.queryParameters['title'],
          ),
        ),
      ),
      GoRoute(
        path: Routes.editExercise,
        pageBuilder: (context, state) => MaterialPage(
          fullscreenDialog: true,
          child: ExerciseFormScreen(
            exerciseId: int.parse(state.pathParameters['id']!),
          ),
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
