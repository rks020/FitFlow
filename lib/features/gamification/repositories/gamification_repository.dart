import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/streak_model.dart';
import '../models/badge_model.dart';

class GamificationRepository {
  final _supabase = Supabase.instance.client;

  String? get _userId => _supabase.auth.currentUser?.id;

  // ── STREAK ──────────────────────────────────────────────────

  Future<StreakModel> getStreak() async {
    final uid = _userId;
    if (uid == null) return StreakModel.empty('');

    try {
      final data = await _supabase
          .from('member_streaks')
          .select()
          .eq('member_id', uid)
          .maybeSingle();

      if (data == null) return StreakModel.empty(uid);
      return StreakModel.fromJson(data);
    } catch (e) {
      debugPrint('getStreak error: $e');
      return StreakModel.empty(uid ?? '');
    }
  }

  /// Ders katılımı veya su hedefi tamamlandığında çağır
  Future<StreakModel> recordActivity() async {
    final uid = _userId;
    if (uid == null) return StreakModel.empty('');

    try {
      final existing = await getStreak();
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);

      int newStreak = existing.currentStreak;
      int longestStreak = existing.longestStreak;
      final lastDate = existing.lastActivityDate;

      if (lastDate == null) {
        // İlk aktivite
        newStreak = 1;
      } else {
        final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
        final diff = todayDate.difference(lastDay).inDays;
        if (diff == 0) {
          // Bugün zaten işaretlendi, değişme
          return existing;
        } else if (diff == 1) {
          // Ardışık gün
          newStreak = existing.currentStreak + 1;
        } else {
          // Zincir kırıldı
          newStreak = 1;
        }
      }

      if (newStreak > longestStreak) longestStreak = newStreak;

      await _supabase.from('member_streaks').upsert({
        'member_id': uid,
        'current_streak': newStreak,
        'longest_streak': longestStreak,
        'last_activity_date': todayDate.toIso8601String().split('T')[0],
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      final updated = StreakModel(
        memberId: uid,
        currentStreak: newStreak,
        longestStreak: longestStreak,
        lastActivityDate: todayDate,
      );

      // Rozet kontrolleri
      await _checkAndAwardStreakBadges(updated);

      return updated;
    } catch (e) {
      debugPrint('recordActivity error: $e');
      return StreakModel.empty(uid);
    }
  }

  Future<void> _checkAndAwardStreakBadges(StreakModel streak) async {
    if (streak.currentStreak >= 7) {
      await awardBadge('streak_7');
    }
    if (streak.currentStreak >= 30) {
      await awardBadge('streak_30');
    }
  }

  // ── BADGES ─────────────────────────────────────────────────

  Future<List<BadgeModel>> getBadges() async {
    final uid = _userId;
    if (uid == null) return [];

    try {
      final data = await _supabase
          .from('member_badges')
          .select()
          .eq('member_id', uid)
          .order('earned_at', ascending: false);

      return (data as List).map((e) => BadgeModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('getBadges error: $e');
      return [];
    }
  }

  Future<void> awardBadge(String badgeType) async {
    final uid = _userId;
    if (uid == null) return;
    try {
      await _supabase.from('member_badges').upsert(
        {'member_id': uid, 'badge_type': badgeType},
        onConflict: 'member_id,badge_type',
        ignoreDuplicates: true,
      );
    } catch (_) {}
  }

  Future<void> markBadgesSeen() async {
    final uid = _userId;
    if (uid == null) return;
    try {
      await _supabase
          .from('member_badges')
          .update({'is_seen': true})
          .eq('member_id', uid)
          .eq('is_seen', false);
    } catch (_) {}
  }

  // ── FIT POINTS ─────────────────────────────────────────────

  Future<int> getTotalPoints() async {
    final uid = _userId;
    if (uid == null) return 0;
    try {
      final data = await _supabase
          .from('fit_points')
          .select('points')
          .eq('member_id', uid);
      return (data as List)
          .fold<int>(0, (sum, row) => sum + ((row['points'] as int?) ?? 0));
    } catch (e) {
      debugPrint('getTotalPoints error: $e');
      return 0;
    }
  }

  Future<void> addPoints(String actionType, int points) async {
    final uid = _userId;
    if (uid == null) return;

    // Aynı gün aynı action_type için mükerrer engelle
    final today = DateTime.now();
    final todayStart =
        DateTime(today.year, today.month, today.day).toUtc().toIso8601String();

    try {
      // Hangi milestone bugün kullanıldı kontrol et
      final existing = await _supabase
          .from('fit_points')
          .select('id')
          .eq('member_id', uid)
          .eq('action_type', actionType)
          .gte('earned_at', todayStart)
          .maybeSingle();

      if (existing != null) return; // Bugün zaten eklendi

      // Organization id al
      final memberData = await _supabase
          .from('members')
          .select('organization_id')
          .eq('id', uid)
          .maybeSingle();

      if (memberData == null) return;

      await _supabase.from('fit_points').insert({
        'member_id': uid,
        'organization_id': memberData['organization_id'],
        'points': points,
        'action_type': actionType,
      });
    } catch (e) {
      debugPrint('addPoints error: $e');
    }
  }

  // ── LEADERBOARD ────────────────────────────────────────────

  Future<List<LeaderboardEntry>> getLeaderboard() async {
    final uid = _userId;
    if (uid == null) return [];

    try {
      // Kendi organization_id'sini bul
      final memberData = await _supabase
          .from('members')
          .select('organization_id')
          .eq('id', uid)
          .maybeSingle();

      if (memberData == null) return [];

      final orgId = memberData['organization_id'] as String;

      final data = await _supabase
          .from('member_leaderboard')
          .select()
          .eq('organization_id', orgId)
          .order('total_points', ascending: false)
          .limit(50);

      int rank = 1;
      return (data as List).map((e) {
        final entry = LeaderboardEntry.fromJson(
          e,
          isCurrentUser: e['member_id'] == uid,
          rank: rank,
        );
        rank++;
        return entry;
      }).toList();
    } catch (e) {
      debugPrint('getLeaderboard error: $e');
      return [];
    }
  }
}
