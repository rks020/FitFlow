import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workout_model.dart';
import '../../../data/repositories/profile_repository.dart';

class WorkoutRepository {
  final _supabase = Supabase.instance.client;

  Future<List<Workout>> getWorkouts() async {
    // Fetch workouts with their exercises and the inner exercise details
    final response = await _supabase
        .from('workouts')
        .select('''
          *,
          workout_exercises (
            *,
            exercises (*)
          )
        ''')
        .order('created_at', ascending: false);

    return (response as List).map((e) => Workout.fromJson(e)).toList();
  }

  Future<Workout> getWorkout(String id) async {
    final response = await _supabase
        .from('workouts')
        .select('''
          *,
          workout_exercises (
            *,
            exercises (*)
          )
        ''')
        .eq('id', id)
        .single();
    
    return Workout.fromJson(response);
  }

  Future<void> createWorkout({
    required String name,
    String? difficulty,
    String? description,
    required List<Map<String, dynamic>> exercisesData, // List of {exercise_id, sets, reps...}
  }) async {
    final profile = await ProfileRepository().getProfile();
    final orgId = profile?.organizationId;
    if (orgId == null) throw Exception('Organization ID not found');

    // 1. Create Workout Header
    final workoutResponse = await _supabase.from('workouts').insert({
      'organization_id': orgId,
      'created_by': _supabase.auth.currentUser!.id,
      'name': name,
      'difficulty': difficulty,
      'description': description,
    }).select().single();

    final workoutId = workoutResponse['id'];

    // 2. Add Exercises
    if (exercisesData.isNotEmpty) {
      final List<Map<String, dynamic>> rows = [];
      for (int i = 0; i < exercisesData.length; i++) {
        final data = exercisesData[i];
        rows.add({
          'workout_id': workoutId,
          'exercise_id': data['exercise_id'],
          'order_index': i,
          'sets': data['sets'] ?? 3,
          'reps': data['reps'],
          'rest_seconds': data['rest_seconds'] ?? 60,
          'notes': data['notes'],
        });
      }
      await _supabase.from('workout_exercises').insert(rows);
    }
  }

  Future<void> deleteWorkout(String id) async {
    await _supabase.from('workouts').delete().eq('id', id);
  }
}
