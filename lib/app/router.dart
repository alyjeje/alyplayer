import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/onboarding/onboarding_screen.dart';
import '../features/home/home_screen.dart';
import '../features/live/live_screen.dart';
import '../features/series/series_screen.dart';
import '../features/series/series_detail_screen.dart';
import '../features/films/films_screen.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/player/player_screen.dart';
import '../features/import/import_screen.dart';
import '../features/paywall/paywall_screen.dart';
import 'shell_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) async {
      final prefs = await SharedPreferences.getInstance();
      final onboarded = prefs.getBool('onboarding_complete') ?? false;
      final isOnboarding = state.matchedLocation == '/onboarding';
      if (!onboarded && !isOnboarding) return '/onboarding';
      if (onboarded && isOnboarding) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ShellScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/live',
              builder: (context, state) => const LiveScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/series',
              builder: (context, state) => const SeriesScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/films',
              builder: (context, state) => const FilmsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/favorites',
              builder: (context, state) => const FavoritesScreen(),
            ),
          ]),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/import',
        builder: (context, state) => const ImportScreen(),
      ),
      GoRoute(
        path: '/player',
        builder: (context, state) {
          final channelId = state.extra as int?;
          return PlayerScreen(channelId: channelId ?? 0);
        },
      ),
      GoRoute(
        path: '/paywall',
        builder: (context, state) => const PaywallScreen(),
      ),
      GoRoute(
        path: '/series/:seriesId',
        builder: (context, state) {
          final seriesId = int.parse(state.pathParameters['seriesId']!);
          return SeriesDetailScreen(seriesId: seriesId);
        },
      ),
    ],
  );
});
