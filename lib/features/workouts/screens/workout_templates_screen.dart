import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../shared/widgets/glass_card.dart';
import '../models/workout_model.dart';
import '../repositories/workout_repository.dart';
import 'create_workout_screen.dart';

class WorkoutTemplatesScreen extends StatefulWidget {
  const WorkoutTemplatesScreen({super.key});

  @override
  State<WorkoutTemplatesScreen> createState() => _WorkoutTemplatesScreenState();
}

class _WorkoutTemplatesScreenState extends State<WorkoutTemplatesScreen> {
  final _repository = WorkoutRepository();
  List<Workout> _workouts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    try {
      final workouts = await _repository.getWorkouts();
      if (mounted) {
        setState(() {
          _workouts = workouts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _workouts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_add, size: 64, color: Colors.grey[700]),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz program oluşturulmamış.\n" + " butonuna basarak yeni şablon oluşturun.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: _workouts.length,
              itemBuilder: (context, index) {
                final workout = _workouts[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              workout.name,
                              style: AppTextStyles.headline.copyWith(fontSize: 18),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryYellow.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${workout.exercises.length} Hareket',
                                style: AppTextStyles.caption1.copyWith(
                                  color: AppColors.primaryYellow,
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (workout.exercises.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            workout.exercises
                                .map((e) => e.exercise?.name ?? '')
                                .where((name) => name.isNotEmpty)
                                .join(', '),
                            style: AppTextStyles.body.copyWith(color: Colors.grey[400]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ] else if (workout.description != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            workout.description!,
                            style: AppTextStyles.body.copyWith(color: Colors.grey[400]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateWorkoutScreen()),
          );
          if (result == true) {
            _loadWorkouts();
          }
        },
        backgroundColor: AppColors.primaryYellow,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}
