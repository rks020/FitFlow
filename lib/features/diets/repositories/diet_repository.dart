import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/diet_model.dart';

class DietRepository {
  final _supabase = Supabase.instance.client;

  Future<Diet?> getActiveDiet(String memberId) async {
    final response = await _supabase
        .from('diets')
        .select('*, diet_items(*)')
        .eq('member_id', memberId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;

    final diet = Diet.fromJson(response);
    diet.items.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return diet;
  }

  Future<List<Diet>> getMemberDiets(String memberId) async {
    final response = await _supabase
        .from('diets')
        .select('*, diet_items(*)')
        .eq('member_id', memberId)
        .order('created_at', ascending: false);

    final List<Diet> diets = [];
    for (var d in response as List) {
      final diet = Diet.fromJson(d);
      diet.items.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      diets.add(diet);
    }
    return diets;
  }

  Future<void> createDiet(Diet diet, List<DietItem> items) async {
    final Map<String, dynamic> dietData = {
      'member_id': diet.memberId,
      'start_date': diet.startDate.toIso8601String(),
      'end_date': diet.endDate?.toIso8601String(),
      'notes': diet.notes,
      'status': diet.status,
      'target_calories': diet.targetCalories,
    };

    // Eğer trainer id varsa ekle (hoca önerisi)
    if (diet.trainerId != null) {
      dietData['trainer_id'] = diet.trainerId;
    }
    // Kimin girdiğini tut
    if (diet.submittedBy != null) {
      dietData['submitted_by'] = diet.submittedBy;
    }

    final dietResponse = await _supabase.from('diets').insert(dietData).select().single();
    final dietId = dietResponse['id'];

    final itemsData = items.map((item) {
      final json = item.toJson();
      json['diet_id'] = dietId;
      return json;
    }).toList();

    if (itemsData.isNotEmpty) {
      await _supabase.from('diet_items').insert(itemsData);
    }
  }

  Future<void> updateDiet(Diet diet, List<DietItem> newItems) async {
    await _supabase.from('diets').update({
      'notes': diet.notes,
      'target_calories': diet.targetCalories,
    }).eq('id', diet.id);

    await _supabase.from('diet_items').delete().eq('diet_id', diet.id);

    final itemsData = newItems.map((item) {
      final json = item.toJson();
      json['diet_id'] = diet.id;
      return json;
    }).toList();

    if (itemsData.isNotEmpty) {
      await _supabase.from('diet_items').insert(itemsData);
    }
  }

  /// Hocanın değerlendirme yorumu ve durumu güncelleme
  Future<void> evaluateDiet(String dietId, {required String status, String? comment}) async {
    await _supabase.from('diets').update({
      'status': status,
      if (comment != null) 'trainer_comment': comment,
    }).eq('id', dietId);
  }

  Future<void> deleteDiet(String dietId) async {
    await _supabase.from('diets').delete().eq('id', dietId);
  }
}
