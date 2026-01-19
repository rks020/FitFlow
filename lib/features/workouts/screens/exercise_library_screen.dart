import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../models/exercise_model.dart';
import '../repositories/exercise_repository.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  final _repository = ExerciseRepository();
  List<Exercise> _exercises = [];
  List<Exercise> _filteredExercises = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExercises();
    _searchController.addListener(_filterExercises);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    try {
      final exercises = await _repository.getExercises();
      if (mounted) {
        setState(() {
          _exercises = exercises;
          _filteredExercises = exercises;
          _isLoading = false;
        });
        _filterExercises(); // Re-apply filter if search text exists
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomSnackBar.showError(context, 'Hareketler yüklenirken hata oluştu');
      }
    }
  }

  void _filterExercises() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredExercises = _exercises.where((e) {
        final matchName = e.name.toLowerCase().contains(query);
        final matchMuscle = e.targetMuscle?.toLowerCase().contains(query) ?? false;
        return matchName || matchMuscle;
      }).toList();
    });
  }

  // Pre-defined exercises
  final List<Map<String, String>> _defaultExercises = [
    {'name': 'Bench Press', 'muscle': 'Göğüs'},
    {'name': 'Incline Bench Press', 'muscle': 'Göğüs'},
    {'name': 'Dumbbell Fly', 'muscle': 'Göğüs'},
    {'name': 'Push Up', 'muscle': 'Göğüs'},
    {'name': 'Shoulder Press', 'muscle': 'Omuz'},
    {'name': 'Lateral Raise', 'muscle': 'Omuz'},
    {'name': 'Front Raise', 'muscle': 'Omuz'},
    {'name': 'Squat', 'muscle': 'Bacak'},
    {'name': 'Leg Press', 'muscle': 'Bacak'},
    {'name': 'Leg Extension', 'muscle': 'Bacak'},
    {'name': 'Lunge', 'muscle': 'Bacak'},
    {'name': 'Deadlift', 'muscle': 'Sırt/Bacak'},
    {'name': 'Lat Pulldown', 'muscle': 'Sırt'},
    {'name': 'Seated Row', 'muscle': 'Sırt'},
    {'name': 'Pull Up', 'muscle': 'Sırt'},
    {'name': 'Barbell Curl', 'muscle': 'Kol - Biceps'},
    {'name': 'Hammer Curl', 'muscle': 'Kol - Biceps'},
    {'name': 'Triceps Pushdown', 'muscle': 'Kol - Triceps'},
    {'name': 'Dips', 'muscle': 'Kol - Triceps'},
    {'name': 'Plank', 'muscle': 'Karın'},
  ];

  Future<void> _showAddDefaultsDialog() async {
    // 1. Filter out existing ones
    final existingNames = _exercises.map((e) => e.name.toLowerCase()).toSet();
    final availableDefaults = _defaultExercises.where((d) {
      return !existingNames.contains(d['name']!.toLowerCase());
    }).toList();

    if (availableDefaults.isEmpty) {
      if (mounted) {
        CustomSnackBar.showInfo(context, 'Tüm varsayılan hareketler zaten ekli.');
      }
      return;
    }

    // 2. Local state for selection
    final selectedIndexes = Set<int>.from(List.generate(availableDefaults.length, (i) => i));

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceDark,
              title: Text('Varsayılan Hareketler', style: AppTextStyles.headline.copyWith(color: Colors.white)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Kütüphanenize eklemek istediğiniz hareketleri seçin:',
                      style: AppTextStyles.body.copyWith(color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: availableDefaults.length,
                        separatorBuilder: (_, __) => Divider(color: Colors.grey[800], height: 1),
                        itemBuilder: (context, index) {
                          final item = availableDefaults[index];
                          final isSelected = selectedIndexes.contains(index);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item['name']!, style: const TextStyle(color: Colors.white)),
                            subtitle: Text(item['muscle']!, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                            trailing: Checkbox(
                              value: isSelected,
                              activeColor: AppColors.primaryYellow,
                              checkColor: Colors.black,
                              side: BorderSide(color: Colors.grey[600]!),
                              onChanged: (val) {
                                setStateDialog(() {
                                  if (val == true) {
                                    selectedIndexes.add(index);
                                  } else {
                                    selectedIndexes.remove(index);
                                  }
                                });
                              },
                            ),
                            onTap: () {
                              setStateDialog(() {
                                if (isSelected) {
                                  selectedIndexes.remove(index);
                                } else {
                                  selectedIndexes.add(index);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('İptal', style: TextStyle(color: Colors.grey[400])),
                ),
                TextButton(
                  onPressed: () async {
                    if (selectedIndexes.isEmpty) return;
                    Navigator.pop(context);

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ekleniyor...')),
                      );
                    }

                    // Batch create (looping)
                    int addedCount = 0;
                    for (final index in selectedIndexes) {
                      final item = availableDefaults[index];
                      try {
                        await _repository.createExercise(
                          name: item['name']!,
                          targetMuscle: item['muscle']!,
                        );
                        addedCount++;
                      } catch (e) {
                         // Continue even if one fails
                         debugPrint('Failed to add ${item['name']}: $e');
                      }
                    }

                    await _loadExercises();

                    if (mounted) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      CustomSnackBar.showSuccess(context, '$addedCount hareket eklendi');
                    }
                  },
                  child: Text(
                    'Ekle (${selectedIndexes.length})', 
                    style: AppTextStyles.headline.copyWith(color: AppColors.primaryYellow, fontSize: 16),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAddExerciseDialog() async {
    final nameController = TextEditingController();
    final muscleController = TextEditingController();
    final videoController = TextEditingController();
    
    // Pre-defined muscle groups for suggestion (could be a dropdown later)
    // For now, free text is fine.

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Text('Yeni Hareket Ekle', style: AppTextStyles.headline.copyWith(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Hareket Adı (Örn: Bench Press)',
                labelStyle: TextStyle(color: Colors.grey[400]),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey[700]!)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryYellow)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: muscleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Hedef Bölge (Örn: Göğüs)',
                labelStyle: TextStyle(color: Colors.grey[400]),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey[700]!)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryYellow)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: videoController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Video URL (Opsiyonel)',
                labelStyle: TextStyle(color: Colors.grey[400]),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey[700]!)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryYellow)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal', style: TextStyle(color: Colors.grey[400])),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              
              try {
                Navigator.pop(context); // Close dialog first
                
                // Show loading indicator
                if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ekleniyor...')),
                  );
                }

                await _repository.createExercise(
                  name: nameController.text.trim(),
                  targetMuscle: muscleController.text.trim(),
                  videoUrl: videoController.text.isEmpty ? null : videoController.text.trim(),
                );
                
                await _loadExercises(); // Refresh list
                
                if (mounted) {
                   ScaffoldMessenger.of(context).hideCurrentSnackBar();
                   CustomSnackBar.showSuccess(context, 'Hareket başarıyla eklendi');
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  CustomSnackBar.showError(context, 'Hata: $e');
                }
              }
            },
            child: Text('Kaydet', style: TextStyle(color: AppColors.primaryYellow, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.transparent, // Inherits ambient background
      body: Column(
        children: [
          // Search Bar & Defaults Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    borderRadius: BorderRadius.circular(12),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Hareket ara...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: InputBorder.none,
                        icon: Icon(Icons.search, color: AppColors.primaryYellow),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: _showAddDefaultsDialog,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primaryYellow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.playlist_add_rounded, color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
          
          // List
          Expanded(
            child: _exercises.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fitness_center, size: 64, color: Colors.grey[700]),
                      const SizedBox(height: 16),
                      Text(
                        'Henüz hareket eklenmemiş.\n" + " butonuna basarak ekleyin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: _filteredExercises.length,
                  itemBuilder: (context, index) {
                    final exercise = _filteredExercises[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        padding: const EdgeInsets.all(16),
                        borderRadius: BorderRadius.circular(16),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.accentBlue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.accentBlue.withOpacity(0.3)),
                              ),
                              child: const Icon(Icons.fitness_center, color: AppColors.accentBlue),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    exercise.name,
                                    style: AppTextStyles.headline.copyWith(fontSize: 16),
                                  ),
                                  if (exercise.targetMuscle != null && exercise.targetMuscle!.isNotEmpty)
                                    Text(
                                      exercise.targetMuscle!,
                                      style: AppTextStyles.caption1.copyWith(color: Colors.grey[400]),
                                    ),
                                ],
                              ),
                            ),
                            // Optional: Add delete/edit button here for admins
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExerciseDialog,
        backgroundColor: AppColors.primaryYellow,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}
