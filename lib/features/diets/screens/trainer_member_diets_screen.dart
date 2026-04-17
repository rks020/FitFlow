import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../shared/widgets/ambient_background.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_snackbar.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../models/diet_model.dart';
import '../repositories/diet_repository.dart';
import 'create_diet_screen.dart';

class TrainerMemberDietsScreen extends StatefulWidget {
  final String memberId;
  final String memberName;

  const TrainerMemberDietsScreen({
    super.key,
    required this.memberId,
    required this.memberName,
  });

  @override
  State<TrainerMemberDietsScreen> createState() => _TrainerMemberDietsScreenState();
}

class _TrainerMemberDietsScreenState extends State<TrainerMemberDietsScreen> {
  final _repository = DietRepository();
  bool _isLoading = true;
  List<Diet> _diets = [];

  @override
  void initState() {
    super.initState();
    _loadDiets();
  }

  Future<void> _loadDiets() async {
    setState(() => _isLoading = true);
    try {
      final diets = await _repository.getMemberDiets(widget.memberId);
      if (mounted) {
        setState(() {
          _diets = diets;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'Diyetler yüklenirken hata oluştu: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteDiet(String dietId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Text('Diyeti Sil', style: AppTextStyles.title3),
        content: Text('Bu diyet programını silmek istediğinize emin misiniz?', style: AppTextStyles.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal', style: AppTextStyles.callout),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accentRed),
            child: Text('Sil', style: AppTextStyles.callout),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repository.deleteDiet(dietId);
        _loadDiets();
        if (mounted) CustomSnackBar.showSuccess(context, 'Diyet silindi.');
      } catch (e) {
        if (mounted) CustomSnackBar.showError(context, 'Silme işlemi başarısız: $e');
      }
    }
  }

  /// Hocanın değerlendirme bottom sheet'i
  void _showEvaluation(Diet diet) {
    final commentController = TextEditingController(text: diet.trainerComment ?? '');
    String selectedStatus = diet.status == 'trainer_suggestion' ? 'trainer_suggestion' : (diet.status == 'approved' ? 'approved' : 'needs_revision');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBottomState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Text('Diyet Değerlendirme', style: AppTextStyles.title3.copyWith(color: AppColors.primaryYellow)),
                const SizedBox(height: 20),

                // Durum seçimi
                Text('Durum', style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _statusChip(
                      label: 'Onayla',
                      icon: Icons.check_circle_outline,
                      color: AppColors.accentGreen,
                      value: 'approved',
                      selected: selectedStatus,
                      onTap: () => setBottomState(() => selectedStatus = 'approved'),
                    ),
                    const SizedBox(width: 10),
                    _statusChip(
                      label: 'Revizyon İste',
                      icon: Icons.warning_amber_outlined,
                      color: AppColors.accentRed,
                      value: 'needs_revision',
                      selected: selectedStatus,
                      onTap: () => setBottomState(() => selectedStatus = 'needs_revision'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Yorum alanı
                Text('Yorumun (İsteğe Bağlı)', style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                TextField(
                  controller: commentController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Üyeye feedback yaz...',
                    hintStyle: TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        await _repository.evaluateDiet(
                          diet.id,
                          status: selectedStatus,
                          comment: commentController.text.trim().isEmpty ? null : commentController.text.trim(),
                        );
                        _loadDiets();
                        if (mounted) {
                          CustomSnackBar.showSuccess(
                            context,
                            selectedStatus == 'approved' ? 'Diyet onaylandı.' : 'Revizyon talebi gönderildi.',
                          );
                        }
                      } catch (e) {
                        if (mounted) CustomSnackBar.showError(context, 'Güncelleme başarısız: $e');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryYellow,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Değerlendirmeyi Kaydet',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusChip({
    required String label,
    required IconData icon,
    required Color color,
    required String value,
    required String selected,
    required VoidCallback onTap,
  }) {
    final isSelected = selected == value;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? color : AppColors.textSecondary, size: 18),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    color: isSelected ? color : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Gruplama: Üye diyetleri + Hoca önerileri
    final memberDiets = _diets.where((d) => !d.isTrainerSuggestion).toList();
    final trainerSuggestions = _diets.where((d) => d.isTrainerSuggestion).toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('${widget.memberName} - Diyetler', style: AppTextStyles.headline),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _diets.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.restaurant_menu_rounded, size: 64, color: AppColors.textSecondary.withOpacity(0.4)),
                                const SizedBox(height: 16),
                                Text(
                                  'Henüz diyet kaydı yok.',
                                  style: AppTextStyles.headline.copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadDiets,
                            color: AppColors.primaryYellow,
                            child: ListView(
                              padding: const EdgeInsets.all(20),
                              children: [
                                // Üyenin girdiği diyetler
                                if (memberDiets.isNotEmpty) ...[
                                  _sectionHeader('Üye Tarafından Girilen', Icons.person_outline, AppColors.accentBlue),
                                  const SizedBox(height: 12),
                                  ...memberDiets.map((d) => Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: _buildDietCard(d, isMemberDiet: true),
                                  )),
                                  const SizedBox(height: 8),
                                ],
                                // Hoca önerileri
                                if (trainerSuggestions.isNotEmpty) ...[
                                  _sectionHeader('Hoca Önerileri', Icons.star_outline, AppColors.primaryYellow),
                                  const SizedBox(height: 12),
                                  ...trainerSuggestions.map((d) => Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: _buildDietCard(d, isMemberDiet: false),
                                  )),
                                ],
                              ],
                            ),
                          ),
              ),

              // Hoca Önerisi Ekle butonu
              Padding(
                padding: const EdgeInsets.all(20),
                child: CustomButton(
                  text: 'Öneri Diyet Ekle',
                  icon: Icons.add,
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateDietScreen(
                          memberId: widget.memberId,
                          memberName: widget.memberName,
                          isTrainerAdding: true,
                        ),
                      ),
                    );
                    if (result == true) _loadDiets();
                  },
                  backgroundColor: AppColors.primaryYellow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(title, style: AppTextStyles.headline.copyWith(color: color)),
      ],
    );
  }

  Widget _buildDietCard(Diet diet, {required bool isMemberDiet}) {
    return Dismissible(
      key: Key(diet.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {},
      confirmDismiss: (_) async {
        await _deleteDiet(diet.id);
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tarih + durum + butonlar
            Row(
              children: [
                _buildStatusPill(diet),
                const Spacer(),
                // Hoca önerisini düzenle
                if (!isMemberDiet)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppColors.primaryYellow, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateDietScreen(
                            memberId: widget.memberId,
                            memberName: widget.memberName,
                            existingDiet: diet,
                            isTrainerAdding: true,
                          ),
                        ),
                      );
                      if (result == true) _loadDiets();
                    },
                  ),
                // Üye diyetini değerlendir
                if (isMemberDiet)
                  TextButton.icon(
                    onPressed: () => _showEvaluation(diet),
                    icon: const Icon(Icons.rate_review_outlined, size: 18, color: AppColors.neonCyan),
                    label: const Text('Değerlendir', style: TextStyle(color: AppColors.neonCyan, fontSize: 13)),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            Text(
              'Tarih: ${DateFormat('dd MMM yyyy', 'tr_TR').format(diet.createdAt)}',
              style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary),
            ),

            if (diet.notes != null && diet.notes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(diet.notes!, style: AppTextStyles.body, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],

            // Hocanın önceki yorumunu göster
            if (diet.trainerComment != null && diet.trainerComment!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryYellow.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primaryYellow.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.chat_bubble_outline, size: 14, color: AppColors.primaryYellow),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        diet.trainerComment!,
                        style: AppTextStyles.caption1.copyWith(color: AppColors.primaryYellow),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Öğünler
            if (diet.items.isNotEmpty)
              ExpansionTile(
                shape: Border.all(color: Colors.transparent),
                collapsedShape: Border.all(color: Colors.transparent),
                tilePadding: EdgeInsets.zero,
                title: Text(
                  '${diet.items.length} Öğün  ·  ${diet.totalCalories} kcal',
                  style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary),
                ),
                children: diet.items.map((item) {
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
                          child: Text(item.mealName,
                              style: AppTextStyles.caption2.copyWith(
                                  color: AppColors.primaryYellow, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.content, style: AppTextStyles.body.copyWith(fontSize: 14)),
                              if (item.calories != null)
                                Text('${item.calories} kcal',
                                    style: AppTextStyles.caption2.copyWith(color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(Diet diet) {
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
      default:
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
          Text(label, style: AppTextStyles.caption2.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
