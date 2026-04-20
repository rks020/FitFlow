import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../gamification/repositories/gamification_repository.dart';
import '../models/water_log_model.dart';
import '../repositories/water_repository.dart';
import '../repositories/water_repository.dart';

class WaterTrackerWidget extends StatefulWidget {
  const WaterTrackerWidget({super.key});

  @override
  State<WaterTrackerWidget> createState() => _WaterTrackerWidgetState();
}

class _WaterTrackerWidgetState extends State<WaterTrackerWidget> {
  final _repository = WaterRepository();
  bool _isLoading = true;
  List<WaterLog> _logs = [];
  int _totalIntake = 0;
  final int _goal = 3000;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadNotificationPref();
  }

  Future<void> _loadNotificationPref() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final res = await Supabase.instance.client
          .from('members')
          .select('water_notification_enabled')
          .eq('id', user.id)
          .maybeSingle();

      if (res != null && mounted) {
        setState(() {
          _notificationsEnabled = res['water_notification_enabled'] == true;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleNotifications(bool value) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Optimistic UI update
    setState(() {
      _notificationsEnabled = value;
    });

    try {
      await Supabase.instance.client
          .from('members')
          .update({'water_notification_enabled': value})
          .eq('id', user.id);
    } catch (e) {
      // Revert if error
      if (mounted) {
        setState(() {
          _notificationsEnabled = !value;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Hata: $e'), backgroundColor: AppColors.accentRed),
        );
      }
    }
  }

  Future<void> _loadData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final logs = await _repository.getDailyWaterLogs(user.id, DateTime.now());
      int sum = 0;
      for (var l in logs) {
        sum += l.amountMl;
      }

      if (mounted) {
        setState(() {
          _logs = logs;
          _totalIntake = sum;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addWater(int amount) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Optimistic update
    setState(() {
      _totalIntake += amount;
    });

    try {
      await _repository.addWater(user.id, amount);
      
      // Update gamification streak and points
      final profile = await Supabase.instance.client.from('profiles').select('id').eq('id', user.id).maybeSingle();
      if (profile != null) {
          // If water goal reached today, update streak
          if (_totalIntake >= _goal && (_totalIntake - amount) < _goal) {
              final gamification = GamificationRepository();
              await gamification.recordActivity();
              await gamification.addPoints('water_goal', 50);
              
              if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: const [
                          Text('💧', style: TextStyle(fontSize: 20)),
                          SizedBox(width: 8),
                          Text('Su hedefine ulaştın! Seri devam ediyor (+50 pt)'),
                        ],
                      ),
                      backgroundColor: AppColors.accentGreen,
                    ),
                  );
              }
          }
      }

      _loadData();
    } catch (e) {
      // Revert if failed
      if (mounted) {
        setState(() {
          _totalIntake -= amount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Hata: $e'), backgroundColor: AppColors.accentRed),
        );
      }
    }
  }

  Future<void> _undoLast() async {
    if (_logs.isEmpty) return;

    final lastLog = _logs.first; // Since order is descending

    // Optimistic update
    setState(() {
      _totalIntake -= lastLog.amountMl;
      _logs.remove(lastLog);
    });

    try {
      await _repository.deleteWaterLog(lastLog.id);
      _loadData(); // Re-sync
    } catch (e) {
      if (mounted) {
        _loadData(); // Revert
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Hata: $e'), backgroundColor: AppColors.accentRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    double progress = _totalIntake / _goal;
    if (progress > 1.0) progress = 1.0;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.water_drop,
                      color: AppColors.accentBlue, size: 24),
                  const SizedBox(width: 8),
                  Text('Su Takibi',
                      style: AppTextStyles.headline
                          .copyWith(color: AppColors.accentBlue)),
                ],
              ),
              // Bildirimleri aç/kapat toggle
              Row(
                children: [
                  Icon(
                    _notificationsEnabled
                        ? Icons.notifications_active
                        : Icons.notifications_off,
                    color: _notificationsEnabled
                        ? AppColors.accentBlue
                        : AppColors.textSecondary,
                    size: 16,
                  ),
                  Switch(
                    value: _notificationsEnabled,
                    onChanged: _toggleNotifications,
                    activeColor: AppColors.accentBlue,
                    activeTrackColor: AppColors.accentBlue.withOpacity(0.3),
                    inactiveThumbColor: AppColors.textSecondary,
                    inactiveTrackColor: AppColors.surfaceLight,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$_totalIntake ml',
                      style: AppTextStyles.headline.copyWith(fontSize: 24)),
                  Text('/ $_goal ml Hedef',
                      style: AppTextStyles.caption1
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
              if (_logs.isNotEmpty)
                IconButton(
                  onPressed: _undoLast,
                  icon: const Icon(Icons.undo, color: AppColors.textSecondary),
                  tooltip: 'Geri Al',
                )
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.surfaceLight,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? AppColors.accentGreen : AppColors.accentBlue,
              ),
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _addWater(250),
                  icon: const Icon(Icons.local_drink,
                      color: Colors.white, size: 18),
                  label: const Text('+1 Bardak',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentBlue.withOpacity(0.8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _addWater(500),
                  icon: const Icon(Icons.water_drop,
                      color: Colors.black, size: 18),
                  label: const Text('+1 Şişe',
                      style: TextStyle(color: Colors.black)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentBlue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
