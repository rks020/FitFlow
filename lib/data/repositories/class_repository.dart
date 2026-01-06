import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/class_session.dart';
import '../models/class_enrollment.dart';

class ClassRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // --- Sessions ---

  // Get sessions within a date range
  Future<List<ClassSession>> getSessions(DateTime start, DateTime end) async {
    final response = await _client
        .from('class_sessions')
        .select()
        .gte('start_time', start.toIso8601String())
        .lte('end_time', end.toIso8601String())
        .order('start_time', ascending: true);
    
    return (response as List)
        .map((json) => ClassSession.fromSupabaseMap(json))
        .toList();
  }

  // Create a new session
  Future<ClassSession> createSession(ClassSession session) async {
    final response = await _client
        .from('class_sessions')
        .insert(session.toSupabaseMap())
        .select()
        .single();
    
    return ClassSession.fromSupabaseMap(response);
  }

  // Update session
  Future<void> updateSession(ClassSession session) async {
    await _client
        .from('class_sessions')
        .update(session.toSupabaseMap())
        .eq('id', session.id!);
  }

  // Cancel/Delete session
  Future<void> deleteSession(String id) async {
    await _client.from('class_sessions').delete().eq('id', id);
  }

  // --- Enrollments ---

  // Get enrollments for a specific class
  Future<List<ClassEnrollment>> getEnrollments(String classId) async {
    final response = await _client
        .from('class_enrollments')
        .select('*, members(*)') // Fetch member details
        .eq('class_id', classId)
        .order('created_at', ascending: true);
    
    return (response as List)
        .map((json) => ClassEnrollment.fromSupabaseMap(json))
        .toList();
  }

  // Enroll a member
  Future<void> enrollMember(String classId, String memberId) async {
    await _client.from('class_enrollments').insert({
      'class_id': classId,
      'member_id': memberId,
      'status': 'booked',
    });
  }

  // Update enrollment status (attended, cancelled, etc.)
  Future<void> updateEnrollmentStatus(String enrollmentId, String status) async {
    await _client
        .from('class_enrollments')
        .update({'status': status})
        .eq('id', enrollmentId);
  }

  // Remove enrollment
  Future<void> removeEnrollment(String enrollmentId) async {
    await _client.from('class_enrollments').delete().eq('id', enrollmentId);
  }

  // Check capacity
  Future<int> getEnrollmentCount(String classId) async {
    final response = await _client
        .from('class_enrollments')
        .select('*')
        .eq('class_id', classId)
        .count();
    return response.count;
  }

  // Get count of sessions for today
  Future<int> getTodaySessionCount() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final response = await _client
        .from('class_sessions')
        .select('*')
        .gte('start_time', startOfDay.toIso8601String())
        .lte('end_time', endOfDay.toIso8601String())
        .count();
        
    return response.count;
  }
}
