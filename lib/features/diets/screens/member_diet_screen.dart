import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../models/diet_model.dart';
import '../repositories/diet_repository.dart';
import '../widgets/water_tracker_widget.dart';
import 'create_diet_screen.dart';
import 'dart:async';

import '../../gamification/repositories/gamification_repository.dart';

class MemberDietScreen extends StatefulWidget {
  const MemberDietScreen({super.key});

  @override
  State<MemberDietScreen> createState() => _MemberDietScreenState();
}

class _MemberDietScreenState extends State<MemberDietScreen> {
  final _repository = DietRepository();
  final _gamificationRepository = GamificationRepository();
  bool _isLoading = true;
  List<Diet> _diets = [];

  StreamSubscription? _dietSubscription;

  @override
  void initState() {
    super.initState();
    _loadDiets();
    _subscribeToDiet();
  }

  @override
  void dispose() {
    _dietSubscription?.cancel();
    super.dispose();
  }

  Future<void> _subscribeToDiet() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _dietSubscription = Supabase.instance.client
        .from('diets')
        .stream(primaryKey: ['id'])
        .eq('member_id', user.id)
        .listen((data) {
          _loadDiets();
        });
  }

  Future<void> _loadDiets() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final diets = await _repository.getMemberDiets(user.id);
      if (mounted) {
        setState(() {
          _diets = diets;
          _isLoading = false;
        });
        _checkDietPoints();
      }
    } catch (e) {
      debugPrint('Error loading diets: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkDietPoints() async {
    if (_diets.isEmpty) return;
    
    // En güncel onaylı veya hoca önerisi diyeti bul
    final currentDiet = _diets.firstWhere(
      (d) => d.isApproved || d.isTrainerSuggestion,
      orElse: () => _diets.first,
    );

    if (currentDiet.targetCalories != null && 
        currentDiet.totalCalories > 0 &&
        currentDiet.totalCalories <= currentDiet.targetCalories!) {
      // Hedef tutturulmuş, puan ver (addPoints metodu zaten günlük limit kontrolü yapar)
      await _gamificationRepository.addPoints('diet_target', 2);
    }
  }

  Future<void> _navigateToCreate() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateDietScreen(
          memberId: user.id,
          memberName: 'Ben',
          isTrainerAdding: false,
        ),
      ),
    );
    if (result == true) _loadDiets();
  }

  Future<void> _navigateToEdit(Diet diet) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateDietScreen(
          memberId: user.id,
          memberName: 'Ben',
          existingDiet: diet,
          isTrainerAdding: false,
        ),
      ),
    );
    if (result == true) _loadDiets();
  }

  Future<void> _deleteDiet(Diet diet) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceLight,
        title: Text('Diyeti Sil',
            style:
                AppTextStyles.headline.copyWith(color: AppColors.textPrimary)),
        content: Text('Bu beslenme programını silmek istediğine emin misin?',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Sil', style: TextStyle(color: AppColors.accentRed)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      await _repository.deleteDiet(diet.id);
      _loadDiets();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
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

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadDiets,
              color: AppColors.primaryYellow,
              backgroundColor: AppColors.surfaceDark,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const WaterTrackerWidget(),
                    const SizedBox(height: 24),
                    _diets.isEmpty
                        ? _buildEmpty()
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _diets.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 16),
                            itemBuilder: (context, index) =>
                                _buildDietCard(_diets[index]),
                          ),
                  ],
                ),
              ),
            ),
          ),
          // Yeni Ekle Butonu
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _navigateToCreate,
                icon: const Icon(Icons.add, color: Colors.black),
                label: const Text(
                  'Yeni Beslenme Programı Gir',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryYellow,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_rounded,
                size: 48, color: AppColors.textSecondary.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(
              'Henüz bir beslenme programı yok.',
              style:
                  AppTextStyles.title3.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDietCard(Diet diet) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst satır: Badge + tarih + edit butonu
          Row(
            children: [
              _buildStatusBadge(diet),
              const Spacer(),
              // Sadece üyenin kendi girdiği diyetleri düzenlenebilir/silinebilir
              if (!diet.isTrainerSuggestion) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      color: AppColors.primaryYellow, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _navigateToEdit(diet),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.accentRed, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _deleteDiet(diet),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Hocanın yorumu varsa göster
          if (diet.trainerComment != null &&
              diet.trainerComment!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: diet.isApproved
                    ? AppColors.accentGreen.withOpacity(0.1)
                    : AppColors.accentRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: diet.isApproved
                      ? AppColors.accentGreen.withOpacity(0.3)
                      : AppColors.accentRed.withOpacity(0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 16,
                    color: diet.isApproved
                        ? AppColors.accentGreen
                        : AppColors.accentRed,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hoca Yorumu',
                          style: AppTextStyles.caption2.copyWith(
                            color: diet.isApproved
                                ? AppColors.accentGreen
                                : AppColors.accentRed,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(diet.trainerComment!, style: AppTextStyles.body),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Notes
          if (diet.notes != null && diet.notes!.isNotEmpty) ...[
            Text(
              diet.notes!,
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
          ],

          // Öğünler (expandable)
          ExpansionTile(
            shape: Border.all(color: Colors.transparent),
            collapsedShape: Border.all(color: Colors.transparent),
            tilePadding: EdgeInsets.zero,
            title: Row(
              children: [
                Text(
                  '${diet.items.length} Öğün',
                  style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(width: 8),
                Text('·', style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(width: 8),
                Text(
                  '${diet.totalCalories} kcal',
                  style: AppTextStyles.caption1.copyWith(
                    color: diet.targetCalories != null
                        ? (diet.totalCalories <= diet.targetCalories!
                            ? AppColors.accentGreen
                            : AppColors.accentRed)
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (diet.targetCalories != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '(Hedef: ${diet.targetCalories} kcal)',
                    style: AppTextStyles.caption2.copyWith(color: AppColors.textSecondary),
                  ),
                  if (diet.totalCalories <= diet.targetCalories!)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.stars_rounded, color: AppColors.primaryYellow, size: 14),
                    ),
                ],
              ],
            ),
            children: diet.items.map((item) => _buildMealRow(item)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(Diet diet) {
    String label;
    Color color;
    IconData icon;

    switch (diet.status) {
      case 'approved':
        label = 'Onaylandı';
        color = AppColors.accentGreen;
        icon = Icons.check_circle_outline;
        break;
      case 'needs_revision':
        label = 'Revizyon İstendi';
        color = AppColors.accentRed;
        icon = Icons.warning_amber_outlined;
        break;
      case 'trainer_suggestion':
        label = 'Hoca Önerisi';
        color = AppColors.primaryYellow;
        icon = Icons.star_outline;
        break;
      default: // pending
        label = 'Onay Bekliyor';
        color = AppColors.textSecondary;
        icon = Icons.access_time_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: AppTextStyles.caption2
                  .copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildMealRow(DietItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              item.mealName,
              style: AppTextStyles.caption2.copyWith(
                  color: AppColors.primaryYellow, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.content,
                    style: AppTextStyles.body.copyWith(fontSize: 14)),
                if (item.calories != null)
                  Text('${item.calories} kcal',
                      style: AppTextStyles.caption2
                          .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
