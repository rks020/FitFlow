import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/class_session.dart';
import '../models/class_enrollment.dart';

class ClassRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // Upload signature
  Future<String> uploadSignature(Uint8List bytes) async {
    final fileName = 'sig_${DateTime.now().millisecondsSinceEpoch}.png';
    // Just file name, bucket is flat
    final path = fileName;
    
    await _client.storage.from('signatures').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(contentType: 'image/png'),
    );
    
    return _client.storage.from('signatures').getPublicUrl(path);
  }

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

  // Delete future sessions (Series)
  Future<void> deleteSeries(String title, String trainerId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _client
        .from('class_sessions')
        .delete()
        .eq('title', title)
        .eq('trainer_id', trainerId)
        .gte('start_time', now)
        .neq('status', 'completed'); // Don't delete completed ones
  }

  // Complete session and deduct from package
  Future<void> completeSession(String id, String? signatureUrl) async {
    // 1. Update session status
    await _client.from('class_sessions').update({
      'status': 'completed',
      'trainer_signature_url': signatureUrl,
    }).eq('id', id);

    // 2. Deduct sessions for attended members
    await _client.rpc('deduct_sessions_for_class', params: {'session_id': id});
  }

  // Update session time (Delay)
  Future<void> updateSessionTime(String id, DateTime newStart, DateTime newEnd) async {
    await _client.from('class_sessions').update({
      'start_time': newStart.toUtc().toIso8601String(),
      'end_time': newEnd.toUtc().toIso8601String(),
    }).eq('id', id);
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

  // Update enrollment signature
  Future<void> updateEnrollmentSignature(String enrollmentId, String signatureUrl) async {
    await _client.from('class_enrollments').update({
      'student_signature_url': signatureUrl,
    }).eq('id', enrollmentId);
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


  // Get upcoming classes for a member
  Future<List<ClassSession>> getMemberUpcomingClasses(String memberId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    
    // We need to join enrollments with sessions and filter
    final response = await _client
        .from('class_enrollments')
        .select('class_sessions!inner(*)')
        .eq('member_id', memberId)
        .gte('class_sessions.start_time', now)
        .neq('status', 'cancelled')
        .order('class_sessions(start_time)', ascending: true);

    return (response as List)
        .map((e) => ClassSession.fromSupabaseMap(e['class_sessions'] as Map<String, dynamic>))
        .toList();
  }

  // Get completed history (Signature Log)
  Future<List<ClassSession>> getCompletedHistory() async {
    final response = await _client
        .from('class_sessions')
        .select('*, class_enrollments(*, members(name, photo_url))') // Fetch enrollments and member names
        .eq('status', 'completed')
        .order('start_time', ascending: false);

    return (response as List)
        .map((e) {
             final session = ClassSession.fromSupabaseMap(e);
             // Manually attach enrollments if needed, or rely on UI fetching them separately.
             // But wait, ClassSession doesn't store enrollments list.
             // We might need a DTO or just return list of Maps if complex, 
             // but cleaner is to return ClassSession and fetch enrollments or extend ClassSession.
             // For now, let's keep it simple: The UI might need to fetch enrollments per session or we extend ClassSession?
             // Actually, `ClassSession` model doesn't have `enrollments` list.
             // I will modify this to just return sessions, and let UI fetch enrollments, OR
             // better: Modify ClassSession to include optional `enrollments`.
             // Providing `enrollments` in ClassSession is better for performance (1 query).
             return session; 
        }) 
        .toList();
  }

  // Get completed history with enrollments
  Future<List<Map<String, dynamic>>> getCompletedHistoryWithDetails() async {
    final response = await _client
        .from('class_sessions')
        .select('*, class_enrollments(*, members(name, photo_url))')
        .eq('status', 'completed')
        .order('start_time', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }

  // Check for conflicting sessions
  Future<List<Map<String, dynamic>>> findConflictingSessions(DateTime start, DateTime end) async {
    final startStr = start.toUtc().toIso8601String();
    final endStr = end.toUtc().toIso8601String();

    // Overlap formula: (StartA < EndB) and (EndA > StartB)
    final response = await _client
        .from('class_sessions')
        .select()
        .neq('status', 'cancelled') // Ignore cancelled
        .lt('start_time', endStr)
        .gt('end_time', startStr);
    
    return List<Map<String, dynamic>>.from(response);
  }
}
