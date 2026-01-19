import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/custom_button.dart';
import '../models/workout_model.dart';
import '../repositories/workout_assignment_repository.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final String assignmentId;
  const WorkoutDetailScreen({super.key, required this.assignmentId});

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  final _supabase = Supabase.instance.client;
  final _repo = WorkoutAssignmentRepository();
  
  Workout? _workout;
  bool _isCompleted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      // Fetch assignment details + workout details
      final response = await _supabase
          .from('assigned_workouts')
          .select('''
            *,
            workouts (
              *,
              workout_exercises (
                *,
                exercises (*)
              )
            )
          ''')
          .eq('id', widget.assignmentId)
          .single();

      final workoutData = response['workouts'];
      // Need to re-map this to our Workout model manually or via helper
      // Creating a temporary workout object from the joined data
      
      final w = Workout.fromJson(workoutData);
      
      setState(() {
        _workout = w;
        _isCompleted = response['is_completed'] ?? false;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _markComplete() async {
    try {
      await _repo.completeWorkout(widget.assignmentId);
      setState(() {
        _isCompleted = true;
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Antrenman tamamlandı!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_workout == null) return const Scaffold(body: Center(child: Text('Veri bulunamadı')));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(_workout!.name, style: AppTextStyles.headline),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_isCompleted)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.accentGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accentGreen),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.accentGreen),
                    const SizedBox(width: 8),
                    Text('Bu antrenman tamamlandı', style: TextStyle(color: AppColors.accentGreen, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),

            ..._workout!.exercises.map((we) {
               final exName = we.exercise?.name ?? 'Hareket';
               return Padding(
                 padding: const EdgeInsets.only(bottom: 12),
                 child: GlassCard(
                   child: Padding(
                     padding: const EdgeInsets.all(16),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(exName, style: AppTextStyles.headline.copyWith(fontSize: 18)),
                         const SizedBox(height: 8),
                         Row(
                           mainAxisAlignment: MainAxisAlignment.spaceAround,
                           children: [
                             _StatBadge('Set', we.sets.toString()),
                             _StatBadge('Tekrar', we.reps ?? '-'),
                             _StatBadge('Dinlenme', '${we.restSeconds}sn'),
                           ],
                         ),
                         if (we.notes != null && we.notes!.isNotEmpty) ...[
                           const Divider(color: Colors.grey),
                           Text('Not: ${we.notes}', style: TextStyle(color: Colors.grey[400], fontStyle: FontStyle.italic)),
                         ]
                       ],
                     ),
                   ),
                 ),
               );
            }),
            
            const SizedBox(height: 32),
            if (!_isCompleted)
              CustomButton(
                text: 'Tamamlandı Olarak İşaretle',
                onPressed: _markComplete,
                backgroundColor: AppColors.accentGreen,
                foregroundColor: Colors.white,
                width: double.infinity,
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  const _StatBadge(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.headline.copyWith(color: AppColors.primaryYellow, fontSize: 20)),
        Text(label, style: AppTextStyles.caption1.copyWith(color: Colors.grey)),
      ],
    );
  }
}
