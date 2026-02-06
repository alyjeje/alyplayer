import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aly_player/l10n/app_localizations.dart';

import '../../core/providers/providers.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _isLoading = false;

  Future<void> _purchase(String productId) async {
    final service = ref.read(subscriptionServiceProvider);
    final products = service.products;
    final product = products.where((p) => p.id == productId).firstOrNull;
    if (product == null) return;

    setState(() => _isLoading = true);
    try {
      await service.purchase(product);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(subscriptionServiceProvider).restorePurchases();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchases restored')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.premium),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.star, size: 80, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(l10n.unlockPremium,
                      style: theme.textTheme.headlineMedium,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(l10n.premiumDescription,
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 32),

                  // Features list
                  _FeatureRow(
                      icon: Icons.playlist_add,
                      text: l10n.featureUnlimitedPlaylists),
                  _FeatureRow(
                      icon: Icons.hd, text: l10n.featureExternalPlayer),
                  _FeatureRow(
                      icon: Icons.picture_in_picture,
                      text: l10n.featurePiP),
                  _FeatureRow(
                      icon: Icons.lock,
                      text: l10n.featureParentalControls),
                  _FeatureRow(
                      icon: Icons.backup,
                      text: l10n.featureCloudBackup),
                  _FeatureRow(
                      icon: Icons.block, text: l10n.featureNoAds),

                  const SizedBox(height: 32),

                  // Pricing cards
                  _PricingCard(
                    title: l10n.monthly,
                    price: '\$4.99',
                    period: l10n.perMonth,
                    onTap: () => _purchase('aly_player_monthly'),
                  ),
                  const SizedBox(height: 12),
                  _PricingCard(
                    title: l10n.yearly,
                    price: '\$29.99',
                    period: l10n.perYear,
                    badge: l10n.save50,
                    isPrimary: true,
                    onTap: () => _purchase('aly_player_yearly'),
                  ),

                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: _restore,
                    child: Text(l10n.restorePurchases),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.subscriptionDisclaimer,
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center),
                ],
              ),
            ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _PricingCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final String? badge;
  final bool isPrimary;
  final VoidCallback onTap;

  const _PricingCard({
    required this.title,
    required this.price,
    required this.period,
    this.badge,
    this.isPrimary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: isPrimary ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isPrimary
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title, style: theme.textTheme.titleMedium),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(badge!,
                                style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme
                                        .colorScheme.onPrimaryContainer)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(period, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Text(price,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
