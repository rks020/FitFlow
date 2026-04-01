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
import 'package:fitflow/features/auth/screens/forgot_password_screen.dart';
import '../../../core/utils/error_translator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import '../../profile/screens/change_password_screen.dart';

class GymOwnerLoginScreen extends StatefulWidget {
  const GymOwnerLoginScreen({super.key});

  @override
  State<GymOwnerLoginScreen> createState() => _GymOwnerLoginScreenState();
}

class _GymOwnerLoginScreenState extends State<GymOwnerLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isLoginPasswordVisible = false;
  
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

    if (email.isEmpty || password.isEmpty) {
      CustomSnackBar.showError(context, 'Lütfen email ve şifre girin');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _supabase.auth.signInWithPassword(email: email, password: password);
      
      if (mounted && response.session != null) {
        // Check Role
        final userId = response.session!.user.id;
        final profileData = await _supabase
            .from('profiles')
            .select('role')
            .eq('id', userId)
            .maybeSingle();
            
        if (profileData == null || profileData['role'] != 'owner') {
           await _supabase.auth.signOut();
           if (mounted) {
             CustomSnackBar.showError(context, 'Antrenörler antrenör girişinden girmelidir.');
           }
           return;
        }

        // Check password changed status for invited users
        final userMetadata = response.session!.user.userMetadata;
        final passwordChanged = userMetadata?['password_changed'];
        
        if (passwordChanged == false) {
           Navigator.of(context).pushAndRemoveUntil(
             MaterialPageRoute(builder: (context) => const ChangePasswordScreen(isFirstLogin: true)),
             (route) => false,
           );
           return;
        }

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
          (route) => false,
        );
      }

    } on AuthException catch (e) {
      if (mounted) {
         if (e.message.contains('Email not confirmed')) {
           CustomSnackBar.showError(context, 'Lütfen mailinizden hesabınızı onaylayın');
         } else if (e.message.contains('Invalid login credentials') || e.statusCode == '400') {
           CustomSnackBar.showError(
             context, 
             'Giriş bilgileri hatalı. Geçici şifre ile giriyorsanız salon sahibinden aldığınız şifreyi kontrol edin.'
           );
         } else {
           CustomSnackBar.showError(context, ErrorMessageTranslator.translateAuthError(e));
         }
      }
    } catch (e) {
      if (mounted) CustomSnackBar.showError(context, 'Beklenmeyen bir hata oluştu: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _handleGoogleSignIn() async {
     setState(() => _isLoading = true);
     try {
        // 1. Web Client ID (from Supabase Auth Settings -> Google)
       // This MUST match the "Web client ID" in Google Cloud Console
       const webClientId = '431063576237-npfq2tnlukv1hv7cit6lig9mktvmq8pl.apps.googleusercontent.com';

       final GoogleSignIn googleSignIn = GoogleSignIn(
         serverClientId: webClientId,
       );

       await googleSignIn.signOut();
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

          final role = profileData?['role'];
          
          // If user is definitely a member or trainer, block them from Owner App
          if (role == 'member' || role == 'trainer') {
             await _supabase.auth.signOut();
             if (mounted) {
               CustomSnackBar.showError(context, 'Bu hesap bir üye veya antrenör hesabıdır. Lütfen ilgili uygulamayı kullanın.');
             }
             return;
          }

          // If role is null (new) or owner, but no org -> Incomplete Registration
          if (profileData == null || profileData['organization_id'] == null) {
              // Ask for confirmation before assuming they want to create a gym
              if (mounted) {
                 await _showRegistrationConfirmDialog(response.user);
              }
              setState(() => _isLoading = false);
              return; 
          }

          // Check if user has completed invitation (changed password)
          // We use profileData because session metadata might be unreliable during OAuth/Google Sign-In
          // Remove the password_changed check for OAuth users - Consistency with SIWA fix

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

  Future<void> _handleAppleSignIn() async {
     setState(() => _isLoading = true);
     try {
       final rawNonce = _supabase.auth.generateRawNonce();
       final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

       final credential = await SignInWithApple.getAppleIDCredential(
         scopes: [
           AppleIDAuthorizationScopes.email,
           AppleIDAuthorizationScopes.fullName,
         ],
         nonce: hashedNonce,
       );

       final idToken = credential.identityToken;
       if (idToken == null) {
         throw 'Apple giriş bilgisi alınamadı.';
       }

       final response = await _supabase.auth.signInWithIdToken(
         provider: OAuthProvider.apple,
         idToken: idToken,
         nonce: rawNonce,
       );

       if (response.session != null) {
         // Check if user is authorized (has a profile and organization)
         final userId = response.user!.id;
         final profileData = await _supabase
             .from('profiles')
             .select()
             .eq('id', userId)
             .maybeSingle();

          final role = profileData?['role'];
          
          if (role == 'member' || role == 'trainer') {
             await _supabase.auth.signOut();
             if (mounted) {
               CustomSnackBar.showError(context, 'Bu hesap bir üye veya antrenör hesabıdır. Lütfen ilgili uygulamayı kullanın.');
             }
             return;
          }

          if (profileData == null || profileData['organization_id'] == null) {
              if (mounted) {
                 await _showRegistrationConfirmDialog(response.user);
              }
              setState(() => _isLoading = false);
              return; 
          }

          // Remove the password_changed check for OAuth users - Apple Guideline 4
          // OAuth handling itself is sufficient authentication.

         if (mounted) {
           Navigator.of(context).pushAndRemoveUntil(
             MaterialPageRoute(builder: (context) => const DashboardScreen()),
             (route) => false,
           );
         }
       }

     } catch (e) {
        if (mounted) CustomSnackBar.showError(context, 'Apple Giriş Hatası: $e');
     } finally {
        if (mounted) setState(() => _isLoading = false);
     }
  }

  // Inform OAuth Users to register via Website - Apple Guideline 3.1.1
  Future<void> _showRegistrationConfirmDialog(User? user) async {
     return showDialog(
       context: context,
       barrierDismissible: false, 
       builder: (BuildContext context) {
         return AlertDialog(
           backgroundColor: AppColors.surface,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
           title: const Text('Hesap Bulunamadı', style: TextStyle(color: Colors.white)),
           content: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               const Text(
                 'Bu hesap ile FitFlow\'a kayıtlı bir salon bulunamadı.',
                 style: TextStyle(color: Colors.grey),
               ),
               const SizedBox(height: 12),
               const Text(
                 'Yeni bir salon kaydı oluşturmak için lütfen web sitemizi ziyaret edin: fitflow.com.tr',
                 style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                 textAlign: TextAlign.center,
               ),
             ],
           ),
           actions: [
             TextButton(
               child: const Text('Kapat', style: TextStyle(color: AppColors.primaryYellow)),
               onPressed: () async {
                 await _supabase.auth.signOut();
                 Navigator.of(context).pop();
               },
             ),
           ],
         );
       },
     );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent, // Handled by AmbientBackground
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Salon Sahibi Paneli', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: _buildLoginForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      children: [
        GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text(
                'Tekrar Hoşgeldiniz',
                style: AppTextStyles.title2.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Hesabınıza giriş yapın',
                style: AppTextStyles.body.copyWith(color: Colors.grey[400]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              CustomTextField(
                controller: _emailController,
                label: 'Email',
                hint: 'ornek@gmail.com',
                prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primaryYellow),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _passwordController,
                label: 'Şifre',
                hint: '******',
                obscureText: !_isLoginPasswordVisible,
                prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primaryYellow),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isLoginPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () => setState(() => _isLoginPasswordVisible = !_isLoginPasswordVisible),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ForgotPasswordScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'Şifremi Unuttum',
                    style: AppTextStyles.caption1.copyWith(color: Colors.grey[400]),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Giriş Yap',
                onPressed: _handleLogin,
                isLoading: _isLoading,
                backgroundColor: AppColors.primaryYellow,
                foregroundColor: Colors.black,
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
              const SizedBox(height: 16),
              if (Platform.isIOS)
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleAppleSignIn,
                  icon: const Icon(Icons.apple, size: 28),
                  label: const Text('Apple ile Devam Et'),
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
        const SizedBox(height: 24),
        // Registration removed to comply with Apple Guideline 3.1.1
        Center(
          child: Text(
            'Yeni salon kaydı için fitflow.com.tr adresini ziyaret edin.',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ),
      ],
    );
  }

  // Note: _buildRegisterForm was removed to comply with Apple Guideline 3.1.1
}
