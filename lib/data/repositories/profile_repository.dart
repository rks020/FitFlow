import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';

class ProfileRepository {
  final _supabase = Supabase.instance.client;

  Future<Profile?> getProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      // Try fetching with organization name
      try {
        final data = await _supabase
            .from('profiles')
            .select('*, organizations!profiles_organization_id_fkey(name)')
            .eq('id', userId)
            .maybeSingle();

        if (data != null) {
          // Extract organization name safely
          String? orgName;
          if (data['organizations'] != null) {
            orgName = data['organizations']['name'];
          }
          return Profile.fromSupabase(data);
        }
      } catch (e) {
        debugPrint('Error fetching with org join: $e');
        // Fallback to simple select if join fails
      }

      // Fallback: simple select
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data == null) return null;
      return Profile.fromSupabase(data);
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      return null;
    }
  }

  Future<void> updateProfile(Profile profile) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final data = profile.toSupabaseMap();
      // Ensure ID is set
      data['id'] = userId;
      
      // Use upsert to handle both insert and update atomically
      // onConflict: 'id' ensures we update based on primary key
      await _supabase.from('profiles').upsert(data);
    } catch (e) {
      debugPrint('Error updating profile: $e');
      rethrow;
    }
  }

  Future<String?> uploadAvatar(File imageFile) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final fileExt = imageFile.path.split('.').last;
      final fileName = '$userId/avatar.$fileExt';
      final filePath = fileName;

      await _supabase.storage.from('avatars').upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(upsert: true),
          );

      final imageUrl = _supabase.storage.from('avatars').getPublicUrl(filePath);
      return '$imageUrl?v=${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      // Handle upload error
      return null;
    }
  }
}
