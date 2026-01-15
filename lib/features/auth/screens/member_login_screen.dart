import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fitflow/core/theme/colors.dart';
import 'package:fitflow/core/theme/text_styles.dart';
import 'package:fitflow/shared/widgets/custom_button.dart';
import 'package:fitflow/shared/widgets/custom_snackbar.dart';
import 'package:fitflow/shared/widgets/custom_text_field.dart';
import 'package:fitflow/shared/widgets/glass_card.dart';
import 'package:fitflow/shared/widgets/ambient_background.dart';
import 'package:fitflow/features/dashboard/screens/dashboard_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../profile/screens/change_password_screen.dart';

class MemberLoginScreen extends StatefulWidget {
  const MemberLoginScreen({super.key});

  @override
  State<MemberLoginScreen> createState() => _MemberLoginScreenState();
}

class _MemberLoginScreenState extends State<MemberLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  final _supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) return;

    setState(() => _isLoading = true);
    
    try {
      final response = await _supabase.auth.signInWithPassword(email: email, password: password);
      
      if (response.session != null) {
        final userMetadata = response.session!.user.userMetadata;
        
        // Use safe access with null check, default to true if null (for legacy users)
        // Only block/redirect if explicitly false
        final passwordChanged = userMetadata?['password_changed'];
        
        if (mounted) {
          if (passwordChanged == false) {
             Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const ChangePasswordScreen(isFirstLogin: true)),
              (route) => false, 
            );
          } else {
             Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const DashboardScreen()),
              (route) => false, 
            );
          }
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        String message;
        if (e.message.contains('invalid_credentials') || e.message.contains('Invalid login credentials')) {
          message = 'Hatalı email veya şifre. Salon sahibinden aldığınız geçici şifreyi kontrol edin.';
        } else {
          message = 'Giriş yapılamadı: ${e.message}';
        }
        CustomSnackBar.showError(context, message);
      }
    } catch (e) {
      if (mounted) CustomSnackBar.showError(context, 'Beklenmeyen bir hata oluştu');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
     setState(() => _isLoading = true);
     try {
       // 1. Web Client ID (from Supabase Auth Settings -> Google)
       // 2. iOS Client ID (from Google Cloud Console)
       const webClientId = '763178042993-oogl3ur576s2nqt2q4qilvre6ettftu5.apps.googleusercontent.com';
       const iosClientId = '763178042993-j0ni4gerolse2h9nt0uidvnku14nlscg.apps.googleusercontent.com';

       final GoogleSignIn googleSignIn = GoogleSignIn(
         serverClientId: webClientId,
         clientId: iosClientId,
       );

       final googleUser = await googleSignIn.signIn();
       final googleAuth = await googleUser?.authentication;

       if (googleAuth == null) {
         throw 'Google girişi iptal edildi.';
       }

       final accessToken = googleAuth.accessToken;
       final idToken = googleAuth.idToken;

       if (idToken == null) {
         throw 'Google ID Token bulunamadı.';
       }

       final response = await _supabase.auth.signInWithIdToken(
         provider: OAuthProvider.google,
         idToken: idToken,
         accessToken: accessToken,
       );

       if (response.session != null) {
         // Check if user is authorized (has a profile and organization)
         final userId = response.user!.id;
         final profileData = await _supabase
             .from('profiles')
             .select()
             .eq('id', userId)
             .maybeSingle();

         if (profileData == null || profileData['organization_id'] == null) {
           // Unauthorized User - Delete/SignOut
           await _supabase.auth.signOut();
           if (mounted) {
             _showUnauthorizedDialog(context);
           }
           return;
         }

         // Check temporary password status
         final passwordChanged = profileData['password_changed'];
         if (passwordChanged == false) {
             await _supabase.auth.signOut();
             if (mounted) {
                 CustomSnackBar.showError(
                   context, 
                   'Lütfen önce eğitmeninizden aldığınız geçici şifre ile normal giriş yaparak şifrenizi belirleyin.'
                 );
             }
             return;
         }

         if (mounted) {
           Navigator.of(context).pushAndRemoveUntil(
             MaterialPageRoute(builder: (context) => const DashboardScreen()),
             (route) => false,
           );
         }
       }

     } catch (e) {
        if (mounted) CustomSnackBar.showError(context, 'Google Giriş Hatası: $e');
     } finally {
        if (mounted) setState(() => _isLoading = false);
     }
  }

  void _showUnauthorizedDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.secondaryBlue, width: 1)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: AppColors.error, size: 28),
            SizedBox(width: 12),
            Text('Yetkisiz Giriş', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Bu sisteme giriş yapabilmek için davet edilmiş olmanız gerekmektedir.\n\nLütfen eğitmeniniz ile iletişime geçin.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tamam', style: TextStyle(color: AppColors.secondaryBlue)),
          ),
        ],
      ),
    );
  }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent, // Handled by AmbientBackground
      appBar: AppBar(
        title: Text('Üye Girişi', style: AppTextStyles.headline),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: Center( // Center the login card
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: GlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Shrink to fit content
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBlue.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.secondaryBlue.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.person, size: 60, color: AppColors.secondaryBlue),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Hoşgeldiniz',
                      style: AppTextStyles.title2.copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Eğitmeninizin size verdiği bilgilerle giriş yapın',
                      style: AppTextStyles.body.copyWith(color: Colors.grey[400]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    CustomTextField(
                      controller: _emailController,
                      label: 'Email Adresiniz',
                      hint: 'Email',
                      prefixIcon: const Icon(Icons.email, color: AppColors.secondaryBlue),
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _passwordController,
                      label: 'Geçici Şifreniz',
                      obscureText: true,
                      prefixIcon: const Icon(Icons.lock, color: AppColors.secondaryBlue),
                    ),
                    const SizedBox(height: 32),
                    CustomButton(
                      text: 'Giriş Yap',
                      backgroundColor: AppColors.secondaryBlue, // Cyan
                      foregroundColor: Colors.white,
                      onPressed: _handleLogin,
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Hesabınız yok mu?\nLütfen eğitmeninizle iletişime geçin.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption1.copyWith(color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 24),
                    Row(children: [
                      const Expanded(child: Divider(color: Colors.grey)), 
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16), 
                        child: Text('veya', style: TextStyle(color: Colors.grey[400]))
                      ), 
                      const Expanded(child: Divider(color: Colors.grey))
                    ]),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                      icon: const Icon(Icons.g_mobiledata, size: 28),
                      label: const Text('Google ile Devam Et'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.grey[700]!),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
