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

  // Fetch all users in the same organization (for New Message screen)
  Future<List<Profile>> getOrganizationUsers() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      // 1. Get my organization ID
      final myProfile = await _supabase
          .from('profiles')
          .select('organization_id')
          .eq('id', userId)
          .single();
      
      final orgId = myProfile['organization_id'];
      if (orgId == null) return [];

      // 2. Fetch all profiles in this organization
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('organization_id', orgId)
          .neq('id', userId) // Exclude myself
          .order('first_name', ascending: true);

      return (response as List).map((e) => Profile.fromSupabase(e)).toList();
    } catch (e) {
      debugPrint('Error fetching organization users: $e');
      return [];
    }
  }
  // Update user presence (Online/Offline)
  Future<void> updatePresence({required bool isOnline}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final updates = {
        'is_online': isOnline,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      // If going offline, update last_seen
      if (!isOnline) {
        updates['last_seen'] = DateTime.now().toUtc().toIso8601String();
      }

      await _supabase.from('profiles').update(updates).eq('id', userId);
    } catch (e) {
      debugPrint('Error updating presence: $e');
      // Don't rethrow, strictly background task
    }
  }
}
