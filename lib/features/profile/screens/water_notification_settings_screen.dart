import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/services/notification_service.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../diets/widgets/water_tracker_widget.dart';

class WaterNotificationSettingsScreen extends StatefulWidget {
  const WaterNotificationSettingsScreen({super.key});

  @override
  State<WaterNotificationSettingsScreen> createState() => _WaterNotificationSettingsScreenState();
}

class _WaterNotificationSettingsScreenState extends State<WaterNotificationSettingsScreen> {
  bool _isEnabled = true;
  int _selectedInterval = 60;
  bool _isLoading = true;

  final List<int> _intervals = [10, 15, 20, 25, 30, 45, 60, 90, 120];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isEnabled = prefs.getBool('water_notifications_enabled') ?? true;
        _selectedInterval = prefs.getInt('water_interval_minutes') ?? 60;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('water_notifications_enabled', _isEnabled);
      await prefs.setInt('water_interval_minutes', _selectedInterval); // canonical key
      
      // Sync to Supabase for server-side push notifications (Android FCM)
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();
            
        if (profile != null && profile['role'] == 'member') {
          await Supabase.instance.client.from('members').update({
            'water_notification_enabled': _isEnabled,
            'water_interval_minutes': _selectedInterval,
          }).eq('id', user.id);
        }
      }
      
      await NotificationService().refreshWaterReminders();
      
      if (mounted) {
        CustomSnackBar.showSuccess(context, 'Ayarlar kaydedildi.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'Hata oluştu: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Su Bildirimi Ayarları'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: AppColors.primaryYellow,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryYellow))
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const WaterTrackerWidget(showSettings: false),
                              const SizedBox(height: 24),
                              GlassCard(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.water_drop_rounded, color: AppColors.accentBlue),
                                            const SizedBox(width: 12),
                                            Text(
                                              'Su Bildirimleri',
                                              style: AppTextStyles.headline.copyWith(fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        Switch(
                                          value: _isEnabled,
                                          onChanged: (val) => setState(() => _isEnabled = val),
                                          activeColor: AppColors.primaryYellow,
                                        ),
                                      ],
                                    ),
                                    const Text(
                                      'Gün içinde su içmeniz gerektiğini hatırlatmak için bildirim gönderilir.',
                                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              if (_isEnabled) ...[
                                Text(
                                  'Hatırlatma Aralığı',
                                  style: AppTextStyles.title3.copyWith(color: Colors.white),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: _intervals.map((interval) {
                                    final isSelected = _selectedInterval == interval;
                                    return GestureDetector(
                                      onTap: () => setState(() => _selectedInterval = interval),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: isSelected ? AppColors.primaryYellow : AppColors.surfaceLight,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isSelected ? AppColors.primaryYellow : Colors.white10,
                                          ),
                                        ),
                                        child: Text(
                                          '$interval dk',
                                          style: TextStyle(
                                            color: isSelected ? Colors.black : Colors.white,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 32),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      CustomButton(
                        text: 'Kaydet ve Güncelle',
                        onPressed: _saveSettings,
                        backgroundColor: AppColors.primaryYellow,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
