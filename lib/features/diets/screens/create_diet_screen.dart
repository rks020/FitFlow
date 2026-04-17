import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_snackbar.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/ambient_background.dart';
import '../models/diet_model.dart';
import '../repositories/diet_repository.dart';

/// [isTrainerAdding]: true → hoca öneri olarak ekliyor (trainer_suggestion)
/// false → üye kendi diyetini giriyor (pending)
class CreateDietScreen extends StatefulWidget {
  final String memberId;
  final String memberName;
  final Diet? existingDiet;
  final bool isTrainerAdding;

  const CreateDietScreen({
    super.key,
    required this.memberId,
    required this.memberName,
    this.existingDiet,
    this.isTrainerAdding = false,
  });

  @override
  State<CreateDietScreen> createState() => _CreateDietScreenState();
}

class _CreateDietScreenState extends State<CreateDietScreen> {
  final _repository = DietRepository();
  bool _isLoading = false;

  final _notesController = TextEditingController();
  final List<MealItemController> _mealControllers = [];

  @override
  void initState() {
    super.initState();
    if (widget.existingDiet != null) {
      _loadExistingDiet();
    } else {
      _addDefaultMeals();
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (var c in _mealControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _loadExistingDiet() {
    _notesController.text = widget.existingDiet!.notes ?? '';
    for (var item in widget.existingDiet!.items) {
      final controller = MealItemController(initialName: item.mealName);
      controller.contentController.text = item.content;
      controller.caloriesController.text = item.calories?.toString() ?? '';
      _mealControllers.add(controller);
    }
  }

  void _addDefaultMeals() {
    _addMeal(name: 'Kahvaltı');
    _addMeal(name: 'Öğle Yemeği');
    _addMeal(name: 'Ara Öğün');
    _addMeal(name: 'Akşam Yemeği');
  }

  void _addMeal({String? name}) {
    setState(() {
      _mealControllers.add(MealItemController(initialName: name));
    });
  }

  void _removeMeal(int index) {
    setState(() {
      _mealControllers[index].dispose();
      _mealControllers.removeAt(index);
    });
  }

  Future<void> _saveDiet() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      final items = _mealControllers.asMap().entries.map((entry) {
        final index = entry.key;
        final controller = entry.value;
        return DietItem(
          mealName: controller.nameController.text.trim(),
          content: controller.contentController.text.trim(),
          calories: int.tryParse(controller.caloriesController.text.trim()),
          orderIndex: index,
        );
      }).where((item) => item.content.isNotEmpty).toList();

      if (items.isEmpty) {
        CustomSnackBar.showError(context, 'En az bir öğün içeriği girmelisiniz.');
        setState(() => _isLoading = false);
        return;
      }

      final diet = Diet(
        id: widget.existingDiet?.id ?? '',
        memberId: widget.memberId,
        // Hoca ekliyorsa trainer_id set et ve status = trainer_suggestion
        trainerId: widget.isTrainerAdding ? currentUser.id : null,
        submittedBy: currentUser.id,
        status: widget.isTrainerAdding ? 'trainer_suggestion' : (widget.existingDiet?.status ?? 'pending'),
        startDate: widget.existingDiet?.startDate ?? DateTime.now(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: widget.existingDiet?.createdAt ?? DateTime.now(),
      );

      if (widget.existingDiet != null) {
        await _repository.updateDiet(diet, items);
        if (mounted) {
          CustomSnackBar.showSuccess(context, 'Diyet programı başarıyla güncellendi.');
          Navigator.pop(context, true);
        }
      } else {
        await _repository.createDiet(diet, items);
        if (mounted) {
          CustomSnackBar.showSuccess(
            context,
            widget.isTrainerAdding
                ? 'Öneri diyet başarıyla oluşturuldu.'
                : 'Beslenme programınız gönderildi. Hoca değerlendirme yapacak.',
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'Diyet oluşturulurken hata: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingDiet != null;
    String title;
    if (widget.isTrainerAdding) {
      title = isEditing ? 'Öneri Düzenle' : '${widget.memberName} - Öneri Diyet';
    } else {
      title = isEditing ? 'Diyetimi Düzenle' : 'Diyetimi Gir';
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(title, style: AppTextStyles.headline),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bilgi banner'ı
                if (!widget.isTrainerAdding) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.accentBlue.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.accentBlue.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.accentBlue, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Girdiğin beslenme programı hocanın değerlendirmesine gönderilecek.',
                            style: AppTextStyles.caption1.copyWith(color: AppColors.accentBlue),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (widget.isTrainerAdding) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primaryYellow.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryYellow.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star_outline, color: AppColors.primaryYellow, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Bu diyet üyeye "Hoca Önerisi" olarak görünecek.',
                            style: AppTextStyles.caption1.copyWith(color: AppColors.primaryYellow),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Genel Bilgiler',
                        style: AppTextStyles.headline.copyWith(color: AppColors.primaryYellow),
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _notesController,
                        label: 'Diyet Notları',
                        hint: 'Örn: Su tüketimine dikkat edilecek...',
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Öğünler', style: AppTextStyles.title3),
                    TextButton.icon(
                      onPressed: _addMeal,
                      icon: const Icon(Icons.add, color: AppColors.neonCyan),
                      label: const Text('Öğün Ekle', style: TextStyle(color: AppColors.neonCyan)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _mealControllers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final controller = _mealControllers[index];
                    return _buildMealItem(index, controller);
                  },
                ),

                const SizedBox(height: 30),
                CustomButton(
                  text: isEditing
                      ? 'Değişiklikleri Kaydet'
                      : (widget.isTrainerAdding ? 'Öneri Olarak Kaydet' : 'Gönder'),
                  onPressed: _saveDiet,
                  isLoading: _isLoading,
                  backgroundColor: widget.isTrainerAdding ? AppColors.primaryYellow : AppColors.accentGreen,
                  foregroundColor: widget.isTrainerAdding ? Colors.black : Colors.white,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMealItem(int index, MealItemController controller) {
    return Dismissible(
      key: ObjectKey(controller),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _removeMeal(index),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: controller.nameController,
                    label: 'Öğün Adı',
                    hint: 'Örn: Kahvaltı',
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 100,
                  child: CustomTextField(
                    controller: controller.caloriesController,
                    label: 'Kalori',
                    hint: 'kcal',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: controller.contentController,
              label: 'İçerik',
              hint: '2 yumurta, 50gr yulaf...',
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}

class MealItemController {
  late TextEditingController nameController;
  late TextEditingController contentController;
  late TextEditingController caloriesController;

  MealItemController({String? initialName}) {
    nameController = TextEditingController(text: initialName);
    contentController = TextEditingController();
    caloriesController = TextEditingController();
  }

  void dispose() {
    nameController.dispose();
    contentController.dispose();
    caloriesController.dispose();
  }
}
