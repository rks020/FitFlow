import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

class IAPManager extends ChangeNotifier {
  static final IAPManager _instance = IAPManager._internal();
  static IAPManager get instance => _instance;

  IAPManager._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  
  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;
  
  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Store Product IDs
  static const String _monthlyIdAndroid = 'pro_monthly';
  static const String _yearlyIdAndroid = 'pro_yearly';
  
  static const String _monthlyIdIOS = 'com.ptbodychange.pro_monthly';
  static const String _yearlyIdIOS = 'com.ptbodychange.pro_yearly';

  Set<String> get _productIds {
    if (Platform.isAndroid) {
      return {_monthlyIdAndroid, _yearlyIdAndroid};
    } else if (Platform.isIOS) {
      return {_monthlyIdIOS, _yearlyIdIOS};
    }
    return {};
  }

  Future<void> initialize() async {
    _isAvailable = await _iap.isAvailable();
    if (!_isAvailable) {
      return;
    }

    // if (Platform.isAndroid) {
    //   final InAppPurchaseAndroidPlatformAddition androidAddition =
    //       _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    //   await androidAddition.enablePendingPurchases();
    // }

    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription.cancel(),
      onError: (error) => debugPrint('IAP Error: $error'),
    );

    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    if (!_isAvailable) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      final ProductDetailsResponse response = 
          await _iap.queryProductDetails(_productIds);
      
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('Products not found: ${response.notFoundIDs}');
      }
      
      _products = response.productDetails;
      // Sort: Monthly first, then Yearly
      _products.sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
      
    } catch (e) {
      debugPrint('Error loading products: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> buyProduct(ProductDetails product) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    
    // For auto-renewable subscriptions
    try {
      if (Platform.isIOS) {
         // App Store handles it automatically
      }
      
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('Buy product error: $e');
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show pending UI if needed
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          // Handle error
          debugPrint('Purchase error: ${purchaseDetails.error}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          
          final bool valid = await _verifyPurchase(purchaseDetails);
          if (valid) {
            // Update UI/DB
            await _updateUserSubscription(purchaseDetails);
          }
        }
        
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
    notifyListeners();
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    // Implement server-side verification here ideally
    // For now, we accept it as true since we trust the store response
    // In production, send receipt to your backend (Supabase Function) to verify
    return true;
  }

  Future<void> _updateUserSubscription(PurchaseDetails purchaseDetails) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Get organization ID
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('organization_id')
          .eq('id', user.id)
          .single();
          
      final orgId = profile['organization_id'];
      if (orgId == null) return;
      
      // Determine subscription type and duration
      final productId = purchaseDetails.productID;
      final isYearly = productId.contains('yearly');
      final subscriptionType = isYearly ? 'yearly' : 'monthly';
      
      final now = DateTime.now();
      final expiryDate = isYearly 
          ? DateTime(now.year + 1, now.month, now.day)
          : DateTime(now.year, now.month + 1, now.day);

      // Update Database with all subscription fields
      await Supabase.instance.client.from('organizations').update({
        'subscription_tier': 'pro',
        'subscription_type': subscriptionType,
        'subscription_end_date': expiryDate.toIso8601String(),
        'subscription_status': 'active',
        'updated_at': now.toIso8601String(),
      }).eq('id', orgId);
      
      debugPrint('Subscription updated successfully for Org: $orgId - Type: $subscriptionType, Expiry: $expiryDate');

    } catch (e) {
      debugPrint('Error updating subscription: $e');
    }
  }
  
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
