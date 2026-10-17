import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loggym/routing/routes.dart';
import 'package:loggym/ui/calendar/calendar_screen.dart';
import 'package:loggym/ui/core/app_shell.dart';
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
                path: Routes.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.newSession,
        pageBuilder: (context, state) => const MaterialPage(
          fullscreenDialog: true,
          child: SessionScreen(),
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
