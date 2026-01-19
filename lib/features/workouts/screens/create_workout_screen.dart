import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../models/exercise_model.dart';
import '../repositories/exercise_repository.dart';
import '../repositories/workout_repository.dart';

class CreateWorkoutScreen extends StatefulWidget {
  const CreateWorkoutScreen({super.key});

  @override
  State<CreateWorkoutScreen> createState() => _CreateWorkoutScreenState();
}

class _CreateWorkoutScreenState extends State<CreateWorkoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  
  final _workoutRepo = WorkoutRepository();
  final _exerciseRepo = ExerciseRepository();
  
  // Local state for the builder
  List<Map<String, dynamic>> _addedExercises = []; // {exercise, sets, reps, rest_seconds, notes}
  
  bool _isSaving = false;

  Future<void> _addExercise() async {
    // Show a dialog to select from existing exercises
    final exercises = await _exerciseRepo.getExercises();

    if (!mounted) return;

    final Exercise? selected = await showDialog<Exercise>(
      context: context,
      builder: (context) => _ExercisePickerDialog(exercises: exercises),
    );

    if (selected != null) {
      setState(() {
        _addedExercises.add({
          'exercise': selected,
          'sets': 3,
          'reps': '10',
          'rest_seconds': 60,
          'notes': '',
        });
      });
    }
  }

  Future<void> _saveWorkout() async {
    if (!_formKey.currentState!.validate()) return;
    if (_addedExercises.isEmpty) {
      CustomSnackBar.showError(context, 'En az bir hareket eklemelisiniz.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final exercisesData = _addedExercises.map((e) {
        final exercise = e['exercise'] as Exercise;
        return {
          'exercise_id': exercise.id,
          'sets': int.tryParse(e['sets'].toString()) ?? 3,
          'reps': e['reps'].toString(),
          'rest_seconds': int.tryParse(e['rest_seconds'].toString()) ?? 60,
          'notes': e['notes'],
        };
      }).toList();

      await _workoutRepo.createWorkout(
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        difficulty: 'intermediate', // Could be a dropdown
        exercisesData: exercisesData,
      );

      if (mounted) {
        CustomSnackBar.showSuccess(context, 'Program oluşturuldu!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'Hata: $e');
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fallback if AmbientBackground not wrapped
      appBar: AppBar(
        title: Text('Yeni Program Oluştur', style: AppTextStyles.headline),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Info
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Program Adı (Örn: Hipertrofi A)',
                        labelStyle: TextStyle(color: Colors.grey),
                         enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryYellow)),
                      ),
                      validator: (v) => v!.isEmpty ? 'Gerekli' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Açıklama',
                        labelStyle: TextStyle(color: Colors.grey),
                         enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryYellow)),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Hareketler', style: AppTextStyles.title3),
                  TextButton.icon(
                    onPressed: _addExercise,
                    icon: const Icon(Icons.add, color: AppColors.primaryYellow),
                    label: Text('Hareket Ekle', style: TextStyle(color: AppColors.primaryYellow)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Exercises List
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _addedExercises.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }
                    final item = _addedExercises.removeAt(oldIndex);
                    _addedExercises.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final item = _addedExercises[index];
                  final exercise = item['exercise'] as Exercise;
                  return Card(
                    key: ValueKey(exercise.id + index.toString()), // Unique key for reorder
                    color: AppColors.surfaceDark,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.drag_handle, color: Colors.grey[600]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(exercise.name, style: AppTextStyles.headline.copyWith(fontSize: 16)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _addedExercises.removeAt(index);
                                  });
                                },
                              ),
                            ],
                          ),
                          const Divider(color: Colors.grey),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Set', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    TextFormField(
                                      initialValue: item['sets'].toString(),
                                      style: const TextStyle(color: Colors.white),
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                        border: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primaryYellow)),
                                      ),
                                      onChanged: (val) => item['sets'] = val,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Tekrar', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    TextFormField(
                                      initialValue: item['reps'].toString(),
                                      style: const TextStyle(color: Colors.white),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                        border: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primaryYellow)),
                                      ),
                                      onChanged: (val) => item['reps'] = val,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Dinlenme (sn)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    TextFormField(
                                      initialValue: item['rest_seconds'].toString(),
                                      style: const TextStyle(color: Colors.white),
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                        border: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primaryYellow)),
                                      ),
                                      onChanged: (val) => item['rest_seconds'] = val,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveWorkout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryYellow,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSaving 
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text(
                        'PROGRAMI KAYDET',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExercisePickerDialog extends StatefulWidget {
  final List<Exercise> exercises;
  const _ExercisePickerDialog({required this.exercises});
  @override
  State<_ExercisePickerDialog> createState() => _ExercisePickerDialogState();
}

class _ExercisePickerDialogState extends State<_ExercisePickerDialog> {
  TextEditingController searchController = TextEditingController();
  List<Exercise> filtered = [];

  @override
  void initState() {
    super.initState();
    filtered = widget.exercises;
    searchController.addListener(() {
      final query = searchController.text.toLowerCase();
      setState(() {
        filtered = widget.exercises.where((e) {
          return e.name.toLowerCase().contains(query) || (e.targetMuscle?.toLowerCase().contains(query) ?? false);
        }).toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
        backgroundColor: AppColors.surfaceDark,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          height: 600,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
               Text('Hareket Seç', style: AppTextStyles.headline.copyWith(color: Colors.white)),
               const SizedBox(height: 12),
               TextField(
                 controller: searchController,
                 style: const TextStyle(color: Colors.white),
                 decoration: InputDecoration(
                   hintText: 'Ara...',
                   hintStyle: TextStyle(color: Colors.grey[500]),
                   prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                   filled: true,
                   fillColor: Colors.black12,
                 ),
               ),
               const SizedBox(height: 12),
               Expanded(
                 child: ListView.builder(
                   itemCount: filtered.length,
                   itemBuilder: (context, index) {
                     final ex = filtered[index];
                     return ListTile(
                       title: Text(ex.name, style: const TextStyle(color: Colors.white)),
                       subtitle: Text(ex.targetMuscle ?? '', style: TextStyle(color: Colors.grey[400])),
                       onTap: () => Navigator.pop(context, ex),
                     );
                   },
                 ),
               ),
               TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
            ],
          ),
        ),
    );
  }
}
