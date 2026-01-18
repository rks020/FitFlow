import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/ambient_background.dart';
import 'upgrade_to_pro_screen.dart';

class TrialExpiredScreen extends StatelessWidget {
  const TrialExpiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                
                // Icon
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accentRed.withOpacity(0.3),
                        AppColors.accentBlue.withOpacity(0.3),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accentRed, width: 3),
                  ),
                  child: Icon(
                    Icons.timer_off_rounded,
                    size: 80,
                    color: AppColors.accentRed,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Title
                Text(
                  'Deneme Süreniz Doldu',
                  style: AppTextStyles.largeTitle.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                // Message
                Text(
                  'Ücretsiz 30 günlük deneme süreniz sona erdi. Pro pakete geçerek sınırsız erişim elde edebilirsiniz.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 40),
                
                // Benefits
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.glassBackground.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.workspace_premium_rounded, 
                            color: AppColors.primaryYellow, 
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Pro Paket - ₺399/ay',
                            style: AppTextStyles.title2.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      _buildBenefit('Sınırsız üye ve antrenör'),
                      _buildBenefit('Gelişim raporları'),
                      _buildBenefit('Öncelikli destek'),
                      _buildBenefit('Gelişmiş analitikler'),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // CTA Button
                CustomButton(
                  text: 'Pro\'ya Yükselt',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UpgradeToProScreen(),
                      ),
                    );
                  },
                  icon: Icons.upgrade_rounded,
                  backgroundColor: AppColors.primaryYellow,
                ),
                
                const SizedBox(height: 16),
                
                // Info Text
                Text(
                  'Pro pakete geçene kadar sisteme erişiminiz kısıtlıdır',
                  style: AppTextStyles.caption1.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBenefit(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, 
            color: AppColors.accentGreen, 
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.body,
            ),
          ),
        ],
      ),
    );
  }
}
