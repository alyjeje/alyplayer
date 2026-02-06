import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aly_player/l10n/app_localizations.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;
  bool _disclaimerAccepted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (mounted) context.go('/live');
  }

  void _nextPage() {
    if (_currentPage == 1 && !_disclaimerAccepted) return;
    if (_currentPage < 2) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _currentPage = i),
                physics: _currentPage == 1 && !_disclaimerAccepted
                    ? const NeverScrollableScrollPhysics()
                    : null,
                children: [
                  _WelcomePage(l10n: l10n),
                  _DisclaimerPage(
                    l10n: l10n,
                    accepted: _disclaimerAccepted,
                    onChanged: (v) => setState(() => _disclaimerAccepted = v ?? false),
                  ),
                  _QuickStartPage(l10n: l10n),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: () => _controller.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                      child: Text(l10n.back),
                    )
                  else
                    const SizedBox(width: 80),
                  Row(
                    children: List.generate(3, (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == i ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == i
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )),
                  ),
                  FilledButton(
                    onPressed: (_currentPage == 1 && !_disclaimerAccepted)
                        ? null
                        : _nextPage,
                    child: Text(_currentPage < 2 ? l10n.next : l10n.getStarted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  final AppLocalizations l10n;
  const _WelcomePage({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.play_circle_filled,
              size: 120, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 32),
          Text(l10n.welcomeTitle,
              style: Theme.of(context).textTheme.headlineLarge,
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(l10n.welcomeSubtitle,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _DisclaimerPage extends StatelessWidget {
  final AppLocalizations l10n;
  final bool accepted;
  final ValueChanged<bool?> onChanged;
  const _DisclaimerPage({required this.l10n, required this.accepted, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined,
              size: 80, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(height: 24),
          Text(l10n.disclaimerTitle,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(l10n.disclaimerBody,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          CheckboxListTile(
            value: accepted,
            onChanged: onChanged,
            title: Text(l10n.disclaimerAccept,
                style: Theme.of(context).textTheme.bodyMedium),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
    );
  }
}

class _QuickStartPage extends StatelessWidget {
  final AppLocalizations l10n;
  const _QuickStartPage({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.playlist_add,
              size: 80, color: Theme.of(context).colorScheme.tertiary),
          const SizedBox(height: 24),
          Text(l10n.quickStartTitle,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(l10n.quickStartSubtitle,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
