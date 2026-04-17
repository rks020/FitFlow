import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/water_log_model.dart';

class WaterRepository {
  final _supabase = Supabase.instance.client;

  Future<List<WaterLog>> getDailyWaterLogs(
      String memberId, DateTime date) async {
    // Only get for specific date
    final startOfDay =
        DateTime(date.year, date.month, date.day).toIso8601String();
    final endOfDay =
        DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();

    final response = await _supabase
        .from('water_logs')
        .select('*')
        .eq('member_id', memberId)
        .gte('consumed_at', startOfDay)
        .lte('consumed_at', endOfDay)
        .order('consumed_at', ascending: false);

    return (response as List).map((l) => WaterLog.fromJson(l)).toList();
  }

  Future<void> addWater(String memberId, int amountMl) async {
    await _supabase.from('water_logs').insert({
      'member_id': memberId,
      'amount_ml': amountMl,
      'consumed_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteWaterLog(String id) async {
    await _supabase.from('water_logs').delete().eq('id', id);
  }
}
