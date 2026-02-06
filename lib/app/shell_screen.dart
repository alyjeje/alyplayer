import 'package:flutter/material.dart';
import 'package:aly_player/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

class ShellScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ShellScreen({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
        },
        destinations: [
          NavigationDestination(icon: const Icon(Icons.live_tv), label: l10n.liveTV),
          NavigationDestination(icon: const Icon(Icons.calendar_month), label: l10n.guide),
          NavigationDestination(icon: const Icon(Icons.movie_outlined), label: l10n.vod),
          NavigationDestination(icon: const Icon(Icons.star), label: l10n.favorites),
          NavigationDestination(icon: const Icon(Icons.settings), label: l10n.settings),
        ],
      ),
    );
  }
}
