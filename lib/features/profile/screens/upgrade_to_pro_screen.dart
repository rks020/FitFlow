import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../core/services/iap_manager.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class UpgradeToProScreen extends StatefulWidget {
  const UpgradeToProScreen({super.key});

  @override
  State<UpgradeToProScreen> createState() => _UpgradeToProScreenState();
}

class _UpgradeToProScreenState extends State<UpgradeToProScreen> {
  String _selectedPlan = 'yearly'; // 'monthly' or 'yearly'
  
  @override
  void initState() {
    super.initState();
    _initializeIAP();
  }

  void _initializeIAP() {
    try {
      IAPManager.instance.initialize().then((_) {
        if (mounted) setState(() {});
      }).catchError((error) {
        debugPrint('IAP initialization error: $error');
        if (mounted) setState(() {});
      });
      
      IAPManager.instance.addListener(_onIAPUpdate);
    } catch (e) {
      debugPrint('IAP setup error: $e');
      // Even if IAP fails, screen should still render
    }
  }
  
  void _onIAPUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    IAPManager.instance.removeListener(_onIAPUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Pro Pakete Yükselt',
          style: AppTextStyles.headline.copyWith(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Section
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primaryYellow, AppColors.accentBlue],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      size: 64,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Pro Paket',
                    style: AppTextStyles.largeTitle.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'İşinizi bir üst seviyeye taşıyın',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Pricing Cards
            if (IAPManager.instance.isLoading)
              const Center(child: CircularProgressIndicator(color: AppColors.primaryYellow))
            else
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPlan = 'monthly'),
                      child: _buildProductCard(
                        type: 'monthly',
                        title: 'Aylık',
                        defaultPrice: '₺399',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPlan = 'yearly'),
                      child: _buildProductCard(
                        type: 'yearly',
                        title: 'Yıllık',
                        defaultPrice: '₺3990',
                        badge: '2 AY BEDAVA',
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 32),

            // Features List
            Text(
              'Pro ile Neler Kazanırsınız?',
              style: AppTextStyles.title2.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildFeature(
                    icon: Icons.people_outline_rounded,
                    title: 'Sınırsız Üye',
                    description: 'İstediğiniz kadar üye ekleyin',
                  ),
                  const Divider(height: 32, color: AppColors.glassBorder),
                  _buildFeature(
                    icon: Icons.fitness_center_rounded,
                    title: 'Sınırsız Antrenör',
                    description: 'Ekibinizi büyütün, limit yok',
                  ),
                  const Divider(height: 32, color: AppColors.glassBorder),
                  _buildFeature(
                    icon: Icons.bar_chart_rounded,
                    title: 'Gelişim Raporları',
                    description: 'Detaylı analiz ve grafikler',
                  ),
                  const Divider(height: 32, color: AppColors.glassBorder),
                  _buildFeature(
                    icon: Icons.support_agent_rounded,
                    title: 'Öncelikli Destek',
                    description: '24/7 hızlı yardım',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // CTA Button
            CustomButton(
              text: _getButtonText(),
              onPressed: _handlePurchase,
              icon: Icons.shopping_cart_rounded,
              backgroundColor: AppColors.primaryYellow,
              isLoading: IAPManager.instance.isLoading,
            ),

            const SizedBox(height: 16),

            // Info Text
            Center(
              child: Text(
                '✓ İstediğiniz zaman iptal edebilirsiniz\n✓ Güvenli ödeme',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption1.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard({
    required String type,
    required String title,
    required String defaultPrice,
    String? badge,
  }) {
    // Find product or use default price
    ProductDetails? product;
    try {
      product = IAPManager.instance.products.firstWhere(
        (p) => p.id.contains(type),
      );
    } catch (e) {
      // Product not found, will use default price
      product = null;
    }
    
    final displayPrice = product?.price ?? defaultPrice;
    
    return _buildPricingCard(
      planId: type,
      title: title,
      price: displayPrice,
      period: type == 'monthly' ? '/ay' : '/yıl',
      badge: badge,
    );
  }

  String _getButtonText() {
    if (IAPManager.instance.products.isEmpty) {
      // Fallback text if store not loaded
      return _selectedPlan == 'monthly' ? 'Satın Al - ₺399' : 'Satın Al - ₺3990';
    }
    
    ProductDetails product;
    try {
      product = IAPManager.instance.products.firstWhere(
        (p) => p.id.contains(_selectedPlan),
      );
    } catch (_) {
      product = IAPManager.instance.products.first;
    }
    
    return 'Satın Al - ${product.price}';
  }

  void _handlePurchase() {
    // Check 1: Is IAP available?
    if (!IAPManager.instance.isAvailable) {
      CustomSnackBar.showError(
        context, 
        'Hata: Google Play Store servisi bulunamadı.\n'
        'Telefonunuz Play Store desteklemiyor olabilir.'
      );
      return;
    }
    
    // Check 2: Are products loaded?
    if (IAPManager.instance.products.isEmpty) {
      CustomSnackBar.showError(
        context, 
        'Hata: Ürünler yüklenemedi.\n'
        'Product IDs: pro_monthly, pro_yearly\n'
        'Lütfen Google Play Console\'da bu ürünlerin Aktif olduğundan emin olun.'
      );
      return;
    }
    
    // Check 3: Find the selected product
    ProductDetails? product;
    try {
      product = IAPManager.instance.products.firstWhere(
        (p) => p.id.contains(_selectedPlan),
      );
    } catch (e) {
      product = null;
    }
    
    if (product == null) {
      CustomSnackBar.showError(
        context, 
        'Hata: $_selectedPlan paketi bulunamadı.\n'
        'Yüklenen ürünler: ${IAPManager.instance.products.map((p) => p.id).join(", ")}'
      );
      return;
    }
    
    // All checks passed, attempt purchase
    CustomSnackBar.showSuccess(context, 'Satın alma başlatılıyor: ${product.title}');
    IAPManager.instance.buyProduct(product);
  }

  Widget _buildPricingCard({
    required String planId,
    required String title,
    required String price,
    required String period,
    String? badge,
  }) {
    final isSelected = _selectedPlan == planId;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                colors: [
                  AppColors.primaryYellow.withOpacity(0.2),
                  AppColors.accentBlue.withOpacity(0.2),
                ],
              )
            : null,
        color: isSelected ? null : AppColors.glassBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? AppColors.primaryYellow : AppColors.glassBorder,
          width: isSelected ? 3 : 1,
        ),
      ),
      child: Column(
        children: [
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryYellow, AppColors.accentBlue],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '✓ SEÇİLDİ',
                style: AppTextStyles.caption2.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (badge != null && !isSelected) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge,
                style: AppTextStyles.caption2.copyWith(
                  color: AppColors.background,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            title,
            style: AppTextStyles.subheadline.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: Center(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: price,
                      style: AppTextStyles.title1.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 24, // Reduced font size slightly
                        color: isSelected ? AppColors.primaryYellow : Colors.white,
                      ),
                    ),
                    TextSpan(
                      text: period,
                      style: AppTextStyles.caption1.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeature({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryYellow, AppColors.accentBlue],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.black, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.headline.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
