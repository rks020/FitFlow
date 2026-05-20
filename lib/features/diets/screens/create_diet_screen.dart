import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
  final _targetCaloriesController = TextEditingController();
  final List<MealItemController> _mealControllers = [];

  int _totalCalories = 0;
  int _totalProtein = 0;
  int _totalCarbs = 0;
  int _totalFat = 0;

  void _updateTotals() {
    int cal = 0, pro = 0, carb = 0, fat = 0;
    for (var c in _mealControllers) {
      cal += int.tryParse(c.caloriesController.text) ?? 0;
      pro += int.tryParse(c.proteinController.text) ?? 0;
      carb += int.tryParse(c.carbsController.text) ?? 0;
      fat += int.tryParse(c.fatController.text) ?? 0;
    }
    setState(() {
      _totalCalories = cal;
      _totalProtein = pro;
      _totalCarbs = carb;
      _totalFat = fat;
    });
  }

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
    _targetCaloriesController.dispose();
    for (var c in _mealControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _loadExistingDiet() {
    _notesController.text = widget.existingDiet!.notes ?? '';
    _targetCaloriesController.text = widget.existingDiet!.targetCalories?.toString() ?? '';
    for (var item in widget.existingDiet!.items) {
      final controller = MealItemController(initialName: item.mealName);
      controller.contentController.text = item.content;
      controller.caloriesController.text = item.calories?.toString() ?? '';
      controller.proteinController.text = item.proteinG?.toString() ?? '';
      controller.carbsController.text = item.carbsG?.toString() ?? '';
      controller.fatController.text = item.fatG?.toString() ?? '';
      _mealControllers.add(controller);
    }
    _updateTotals();
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
      _updateTotals();
    });
  }

  Future<void> _saveDiet() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      final items = _mealControllers
          .asMap()
          .entries
          .map((entry) {
            final index = entry.key;
            final controller = entry.value;
            return DietItem(
              mealName: controller.nameController.text.trim(),
              content: controller.contentController.text.trim(),
              calories: int.tryParse(controller.caloriesController.text.trim()),
              proteinG: int.tryParse(controller.proteinController.text.trim()),
              carbsG: int.tryParse(controller.carbsController.text.trim()),
              fatG: int.tryParse(controller.fatController.text.trim()),
              orderIndex: index,
            );
          })
          .where((item) => item.content.isNotEmpty)
          .toList();

      if (items.isEmpty) {
        CustomSnackBar.showError(
            context, 'En az bir öğün içeriği girmelisiniz.');
        setState(() => _isLoading = false);
        return;
      }

      final diet = Diet(
        id: widget.existingDiet?.id ?? '',
        memberId: widget.memberId,
        // Hoca ekliyorsa trainer_id set et ve status = trainer_suggestion
        trainerId: widget.isTrainerAdding ? currentUser.id : null,
        submittedBy: currentUser.id,
        status: widget.isTrainerAdding
            ? 'trainer_suggestion'
            : (widget.existingDiet?.status ?? 'approved'),
        startDate: widget.existingDiet?.startDate ?? DateTime.now(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        targetCalories: int.tryParse(_targetCaloriesController.text.trim()),
        createdAt: widget.existingDiet?.createdAt ?? DateTime.now(),
      );

      if (widget.existingDiet != null) {
        await _repository.updateDiet(diet, items);
        if (mounted) {
          CustomSnackBar.showSuccess(
              context, 'Diyet programı başarıyla güncellendi.');
          Navigator.pop(context, true);
        }
      } else {
        await _repository.createDiet(diet, items);
        if (mounted) {
          CustomSnackBar.showSuccess(
            context,
            widget.isTrainerAdding
                ? 'Öneri diyet başarıyla oluşturuldu.'
                : 'Beslenme programınız başarıyla oluşturuldu.',
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
      title =
          isEditing ? 'Öneri Düzenle' : '${widget.memberName} - Öneri Diyet';
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
                if (widget.isTrainerAdding) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primaryYellow.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primaryYellow.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star_outline,
                            color: AppColors.primaryYellow, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Bu diyet üyeye "Hoca Önerisi" olarak görünecek.',
                            style: AppTextStyles.caption1
                                .copyWith(color: AppColors.primaryYellow),
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
                        style: AppTextStyles.headline
                            .copyWith(color: AppColors.primaryYellow),
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _notesController,
                        label: 'Diyet Notları',
                        hint: 'Örn: Su tüketimine dikkat edilecek...',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _targetCaloriesController,
                        label: 'Günlük Hedef Kalori (Opsiyonel)',
                        hint: 'Örn: 2000',
                        keyboardType: TextInputType.number,
                        prefixIcon: const Icon(Icons.bolt_rounded),
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
                      label: const Text('Öğün Ekle',
                          style: TextStyle(color: AppColors.neonCyan)),
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

                const SizedBox(height: 24),
                
                // Toplam Özet
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Günlük Toplam Özet',
                        style: AppTextStyles.title3.copyWith(color: AppColors.primaryYellow),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSummaryItem('Kalori', '$_totalCalories', 'kcal'),
                          _buildSummaryItem('Protein', '$_totalProtein', 'g'),
                          _buildSummaryItem('Karb.', '$_totalCarbs', 'g'),
                          _buildSummaryItem('Yağ', '$_totalFat', 'g'),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                CustomButton(
                  text: isEditing
                      ? 'Değişiklikleri Kaydet'
                      : (widget.isTrainerAdding
                          ? 'Öneri Olarak Kaydet'
                          : 'Gönder'),
                  onPressed: _saveDiet,
                  isLoading: _isLoading,
                  backgroundColor: widget.isTrainerAdding
                      ? AppColors.primaryYellow
                      : AppColors.accentGreen,
                  foregroundColor:
                      widget.isTrainerAdding ? Colors.black : Colors.white,
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
                    onChanged: (_) => _updateTotals(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: controller.proteinController,
                    label: 'Protein',
                    hint: 'g',
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _updateTotals(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CustomTextField(
                    controller: controller.carbsController,
                    label: 'Karb.',
                    hint: 'g',
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _updateTotals(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CustomTextField(
                    controller: controller.fatController,
                    label: 'Yağ',
                    hint: 'g',
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _updateTotals(),
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
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: controller.isCalculating 
                    ? null 
                    : () => _calculateCalories(controller),
                icon: controller.isCalculating 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryYellow))
                    : const Icon(Icons.auto_awesome, color: AppColors.primaryYellow, size: 18),
                label: Text(
                  controller.isCalculating ? 'Hesaplanıyor...' : 'Otomatik Kalori Hesapla',
                  style: const TextStyle(color: AppColors.primaryYellow, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _calculateCalories(MealItemController controller) async {
    final content = controller.contentController.text.trim();
    if (content.isEmpty) {
      CustomSnackBar.showError(context, 'Lütfen hesaplanacak öğün içeriğini girin.');
      return;
    }

    setState(() {
      controller.isCalculating = true;
    });

    try {
      final prompt = 'Bana sadece JSON formatinda kalori, protein, karbonhidrat ve yag degerlerini sayi olarak dondur. Makrolari GRAM (g) cinsinden hesapla. Degisken isimleri: calories, protein, carbs, fat. Ornek: {"calories": 500, "protein": 30, "carbs": 40, "fat": 20}. Sadece saf JSON ciktisi ver, markdown kod blogu icine alma ve aciklama yazma. Icerik: $content';
      final url = Uri.parse('https://text.pollinations.ai/${Uri.encodeComponent(prompt)}?json=true');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        String result = response.body.trim();
        if (result.startsWith('```json')) {
          result = result.replaceAll('```json', '').replaceAll('```', '').trim();
        }
        
        try {
          final data = jsonDecode(result);
          controller.caloriesController.text = data['calories']?.toString() ?? '';
          controller.proteinController.text = data['protein']?.toString() ?? '';
          controller.carbsController.text = data['carbs']?.toString() ?? '';
          controller.fatController.text = data['fat']?.toString() ?? '';
          _updateTotals();
          CustomSnackBar.showSuccess(context, 'Değerler otomatik olarak hesaplandı!');
        } catch (e) {
          // Fallback if JSON parse fails
          final numericOnly = result.replaceAll(RegExp(r'[^0-9]'), '');
          if (numericOnly.isNotEmpty && numericOnly.length < 5) {
            controller.caloriesController.text = numericOnly;
            _updateTotals();
            CustomSnackBar.showSuccess(context, 'Sadece kalori bulunabildi.');
          } else {
             CustomSnackBar.showError(context, 'Değerler anlaşılamadı. Lütfen içeriği daha net yazın.');
          }
        }
      } else {
        CustomSnackBar.showError(context, 'Hesaplama servisi yanıt vermedi.');
      }
    } catch (e) {
      CustomSnackBar.showError(context, 'Bağlantı hatası: Değerler hesaplanamadı.');
    } finally {
      if (mounted) {
        setState(() {
          controller.isCalculating = false;
        });
      }
    }
  }

  Widget _buildSummaryItem(String label, String value, String unit) {
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: AppTextStyles.title2.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: AppTextStyles.caption2.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

class MealItemController {
  late TextEditingController nameController;
  late TextEditingController contentController;
  late TextEditingController caloriesController;
  late TextEditingController proteinController;
  late TextEditingController carbsController;
  late TextEditingController fatController;
  bool isCalculating = false;

  MealItemController({String? initialName}) {
    nameController = TextEditingController(text: initialName);
    contentController = TextEditingController();
    caloriesController = TextEditingController();
    proteinController = TextEditingController();
    carbsController = TextEditingController();
    fatController = TextEditingController();
  }

  void dispose() {
    nameController.dispose();
    contentController.dispose();
    caloriesController.dispose();
    proteinController.dispose();
    carbsController.dispose();
    fatController.dispose();
  }
}
