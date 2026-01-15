import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../shared/widgets/custom_button.dart';
import 'welcome_screen.dart';

class AccountPendingScreen extends StatelessWidget {
  const AccountPendingScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.mail_lock_outlined,
                size: 80,
                color: AppColors.primaryYellow,
              ),
              const SizedBox(height: 32),
              Text(
                'Hesabınız Henüz Aktif Değil',
                style: AppTextStyles.title2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Hesabınız oluşturuldu ancak şifrenizi belirlemediğiniz için aktif edilmedi.\n\nLütfen e-postanıza (Inbox/Spam) gelen davet bağlantısına tıklayarak şifrenizi belirleyin ve hesabınızı aktifleştirin.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              CustomButton(
                text: 'Giriş Ekranına Dön',
                onPressed: () => _signOut(context),
                isLoading: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
