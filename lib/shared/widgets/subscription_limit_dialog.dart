import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../features/profile/screens/upgrade_to_pro_screen.dart';

class SubscriptionLimitDialog extends StatelessWidget {
  final String limitType; // 'member' or 'trainer'
  final int currentCount;
  final int maxCount;

  const SubscriptionLimitDialog({
    super.key,
    required this.limitType,
    required this.currentCount,
    required this.maxCount,
  });

  @override
  Widget build(BuildContext context) {
    final isMember = limitType == 'member';
    
    return Dialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryYellow, AppColors.accentBlue],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isMember ? Icons.people_outline_rounded : Icons.fitness_center_rounded,
                size: 48,
                color: Colors.black,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Title
            Text(
              'Limite Ulaştınız',
              style: AppTextStyles.title2.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 12),
            
            // Message
            Text(
              isMember
                  ? 'Ücretsiz pakette maksimum $maxCount üye ekleyebilirsiniz. Şu anda $currentCount üyeniz var.'
                  : 'Ücretsiz pakette maksimum $maxCount antrenör ekleyebilirsiniz. Şu anda $currentCount antrenörünüz var.',
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 24),
            
            // Benefits
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accentBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accentBlue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.workspace_premium_rounded, color: AppColors.primaryYellow, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Pro Paket ile:',
                        style: AppTextStyles.headline.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildBenefit('Sınırsız ${isMember ? "üye" : "antrenör"}'),
                  _buildBenefit('Gelişim raporları'),
                  _buildBenefit('Öncelikli destek'),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'İptal',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: CustomButton(
                    text: 'Pro\'ya Yükselt',
                    onPressed: () {
                      Navigator.pop(context);
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
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefit(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.accentBlue, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
