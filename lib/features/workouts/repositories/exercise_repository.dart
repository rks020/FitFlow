import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/exercise_model.dart';
import '../../../data/repositories/profile_repository.dart';

class ExerciseRepository {
  final _supabase = Supabase.instance.client;

  Future<List<Exercise>> getExercises() async {
    final response = await _supabase
        .from('exercises')
        .select()
        .order('name', ascending: true);
    
    return (response as List).map((e) => Exercise.fromJson(e)).toList();
  }

  Future<void> createExercise({
    required String name,
    String? targetMuscle,
    String? videoUrl,
  }) async {
    // Get current user's org ID
    final profile = await ProfileRepository().getProfile();
    final orgId = profile?.organizationId;
    
    if (orgId == null) throw Exception('Organization ID not found');

    await _supabase.from('exercises').insert({
      'organization_id': orgId,
      'created_by': _supabase.auth.currentUser!.id,
      'name': name,
      'target_muscle': targetMuscle,
      'video_url': videoUrl,
    });
  }

  Future<void> deleteExercise(String id) async {
    await _supabase.from('exercises').delete().eq('id', id);
  }
}
