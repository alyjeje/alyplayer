/// In-app purchase subscription service.
///
/// Wraps the `in_app_purchase` plugin to provide a clean API for checking
/// subscription status, purchasing products, and restoring past purchases.
///
/// The service listens to the plugin's purchase stream throughout its
/// lifetime and automatically updates the current [SubscriptionTier].
library;

import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:aly_player/core/models/dtos.dart';

/// Product identifiers registered in App Store Connect / Google Play Console.
class SubscriptionProductIds {
  SubscriptionProductIds._();

  /// Monthly auto-renewing subscription.
  static const String monthly = 'aly_player_premium_monthly';

  /// Yearly auto-renewing subscription.
  static const String yearly = 'aly_player_premium_yearly';

  /// Set of all known product IDs for querying the store.
  static const Set<String> all = {monthly, yearly};
}

/// Service for managing in-app purchase subscriptions.
///
/// Usage:
/// ```dart
/// final service = SubscriptionService();
/// await service.initialise();
/// if (service.isPremium) { /* unlock features */ }
/// ```
class SubscriptionService {
  SubscriptionService({
    InAppPurchase? iapInstance,
  }) : _iap = iapInstance ?? InAppPurchase.instance;

  final InAppPurchase _iap;

  // ── State ─────────────────────────────────────────────────

  /// Current subscription tier.
  SubscriptionTier _tier = SubscriptionTier.free;
  SubscriptionTier get tier => _tier;

  /// Whether the user has an active premium subscription.
  bool get isPremium => _tier == SubscriptionTier.premium;

  /// Available subscription products loaded from the store.
  List<ProductDetails> _products = const [];
  List<ProductDetails> get products => List.unmodifiable(_products);

  /// Whether the store is available on this device.
  bool _storeAvailable = false;
  bool get storeAvailable => _storeAvailable;

  /// Broadcast stream of tier changes so the UI can react.
  final _tierController = StreamController<SubscriptionTier>.broadcast();
  Stream<SubscriptionTier> get tierStream => _tierController.stream;

  /// Stream of error messages for surfacing to the UI.
  final _errorController = StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorController.stream;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  // ── Initialisation ────────────────────────────────────────

  /// Initialises the service: checks store availability, loads products,
  /// and begins listening to the purchase update stream.
  ///
  /// Should be called once at app startup.
  Future<void> initialise() async {
    _storeAvailable = await _iap.isAvailable();
    if (!_storeAvailable) return;

    // Listen to purchase updates.
    _purchaseSubscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error) {
        _errorController.add('Purchase stream error: $error');
      },
    );

    // Load available products.
    await loadProducts();
  }

  // ── Public API ────────────────────────────────────────────

  /// Queries the store for the subscription product details.
  ///
  /// Populates [products] with the results. If the store is unavailable
  /// or the query fails, [products] will remain empty.
  Future<void> loadProducts() async {
    if (!_storeAvailable) return;

    try {
      final response = await _iap.queryProductDetails(
        SubscriptionProductIds.all,
      );

      if (response.notFoundIDs.isNotEmpty) {
        _errorController.add(
          'Products not found in store: ${response.notFoundIDs.join(", ")}',
        );
      }

      _products = response.productDetails;
    } catch (e) {
      _errorController.add('Failed to load products: $e');
    }
  }

  /// Initiates a purchase flow for the given [product].
  ///
  /// The result is delivered asynchronously via the purchase stream and
  /// handled in [_handlePurchaseUpdates].
  Future<void> purchase(ProductDetails product) async {
    if (!_storeAvailable) {
      _errorController.add('Store is not available on this device.');
      return;
    }

    final purchaseParam = PurchaseParam(productDetails: product);

    try {
      // Use buyNonConsumable for subscriptions (the plugin handles the
      // subscription type internally based on the product configuration
      // in the store).
      final started = await _iap.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      if (!started) {
        _errorController.add('Purchase could not be initiated.');
      }
    } catch (e) {
      _errorController.add('Purchase error: $e');
    }
  }

  /// Restores previously purchased subscriptions.
  ///
  /// Useful when a user re-installs the app or switches devices. Restored
  /// purchases are delivered via the purchase stream.
  Future<void> restorePurchases() async {
    if (!_storeAvailable) {
      _errorController.add('Store is not available on this device.');
      return;
    }

    try {
      await _iap.restorePurchases();
    } catch (e) {
      _errorController.add('Restore failed: $e');
    }
  }

  /// Releases resources held by this service.
  Future<void> dispose() async {
    await _purchaseSubscription?.cancel();
    await _tierController.close();
    await _errorController.close();
  }

  // ── Private helpers ────────────────────────────────────────

  /// Processes a batch of purchase updates from the store.
  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      _handlePurchase(purchase);
    }
  }

  /// Processes a single purchase update.
  void _handlePurchase(PurchaseDetails purchase) {
    switch (purchase.status) {
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        // Verify the purchase belongs to one of our known products.
        if (SubscriptionProductIds.all.contains(purchase.productID)) {
          _setTier(SubscriptionTier.premium);
        }
        // Complete the purchase so the store clears its pending state.
        if (purchase.pendingCompletePurchase) {
          _iap.completePurchase(purchase);
        }

      case PurchaseStatus.pending:
        // Purchase is pending (e.g. waiting for parental approval or
        // alternative payment method confirmation). Nothing to do yet.
        break;

      case PurchaseStatus.error:
        _errorController.add(
          purchase.error?.message ?? 'An unknown purchase error occurred.',
        );
        if (purchase.pendingCompletePurchase) {
          _iap.completePurchase(purchase);
        }

      case PurchaseStatus.canceled:
        // User cancelled -- no action required.
        if (purchase.pendingCompletePurchase) {
          _iap.completePurchase(purchase);
        }
    }
  }

  /// Updates the subscription tier and notifies listeners.
  void _setTier(SubscriptionTier newTier) {
    if (_tier == newTier) return;
    _tier = newTier;
    if (!_tierController.isClosed) {
      _tierController.add(newTier);
    }
  }
}
