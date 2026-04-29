import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_snackbar.dart';

class ManageDailyTipScreen extends StatefulWidget {
  const ManageDailyTipScreen({super.key});

  @override
  State<ManageDailyTipScreen> createState() => _ManageDailyTipScreenState();
}

class _ManageDailyTipScreenState extends State<ManageDailyTipScreen> {
  final _controller = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _orgId;

  @override
  void initState() {
    super.initState();
    _loadCurrentTip();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentTip() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('organization_id')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) return;
      _orgId = profile['organization_id'] as String;

      final orgResult = await Supabase.instance.client
          .from('organizations')
          .select('daily_tip')
          .eq('id', _orgId!)
          .maybeSingle();

      if (orgResult != null && orgResult['daily_tip'] != null) {
        _controller.text = orgResult['daily_tip'] as String;
      }
    } catch (e) {
      debugPrint('Error loading daily tip: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveTip() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null || _orgId == null) return;

    setState(() => _isSaving = true);
    try {
      final text = _controller.text.trim();
      
      String? authorName;
      if (text.isNotEmpty) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('first_name, last_name')
            .eq('id', currentUser.id)
            .maybeSingle();
            
        if (profile != null) {
          authorName = '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'.trim();
        }
      }

      await Supabase.instance.client
          .from('organizations')
          .update({
            'daily_tip': text.isEmpty ? null : text,
            'daily_tip_author': text.isEmpty ? null : authorName,
          }).eq('id', _orgId!);

      if (mounted) {
        CustomSnackBar.showSuccess(context, 'Günün sözü başarıyla kaydedildi.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(
            context, 'Günün sözü kaydedilirken hata oluştu: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _clearTip() async {
    _controller.clear();
    await _saveTip();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Günün Sözü / Tüyosu'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryYellow))
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Salonunuz için günün sözünü belirleyin. Bu söz üyelerinizin "Günün Tüyosu" bölümünde varsayılan mesajlar yerine gösterilecektir.',
                    style: AppTextStyles.body.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _controller,
                    maxLines: 5,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText:
                          'Örn: Bugünü de antrenmansız geçirme, başarı sabır ister! 💪',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: AppColors.surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.glassBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.glassBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: AppColors.primaryYellow),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: 'Kaydet',
                    onPressed: _isSaving ? () {} : _saveTip,
                    icon: _isSaving ? Icons.hourglass_top : Icons.save_rounded,
                    backgroundColor: AppColors.primaryYellow,
                  ),
                  const SizedBox(height: 16),
                  if (_controller.text.isNotEmpty)
                    Center(
                      child: TextButton.icon(
                        onPressed: _isSaving ? null : _clearTip,
                        icon: const Icon(Icons.delete_rounded,
                            color: AppColors.accentRed),
                        label: const Text('Kaldır ve Sistem Tüyolarına Dön',
                            style: TextStyle(color: AppColors.accentRed)),
                      ),
                    )
                ],
              ),
            ),
    );
  }
}
