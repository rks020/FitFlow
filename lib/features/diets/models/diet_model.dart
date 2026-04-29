class Diet {
  final String id;
  final String memberId;
  final String? trainerId; // nullable: üye girerken null
  final String? submittedBy; // auth.uid() — kimin girdiğini tutar
  final String status; // pending | approved | needs_revision | trainer_suggestion
  final String? trainerComment; // hocanın değerlendirme yorumu
  final DateTime startDate;
  final DateTime? endDate;
  final String? notes;
  final int? targetCalories;
  final List<DietItem> items;
  final DateTime createdAt;

  Diet({
    required this.id,
    required this.memberId,
    this.trainerId,
    this.submittedBy,
    this.status = 'pending',
    this.trainerComment,
    required this.startDate,
    this.endDate,
    this.items = const [],
    this.notes,
    this.targetCalories,
    required this.createdAt,
  });

  factory Diet.fromJson(Map<String, dynamic> json) {
    return Diet(
      id: json['id'],
      memberId: json['member_id'],
      trainerId: json['trainer_id'],
      submittedBy: json['submitted_by'],
      status: json['status'] ?? 'pending',
      trainerComment: json['trainer_comment'],
      startDate: DateTime.parse(json['start_date']),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      notes: json['notes'],
      targetCalories: json['target_calories'],
      createdAt: DateTime.parse(json['created_at']),
      items: json['diet_items'] != null
          ? (json['diet_items'] as List).map((i) => DietItem.fromJson(i)).toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'member_id': memberId,
      if (trainerId != null) 'trainer_id': trainerId,
      if (submittedBy != null) 'submitted_by': submittedBy,
      'status': status,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'notes': notes,
      if (targetCalories != null) 'target_calories': targetCalories,
    };
  }

  int get totalCalories {
    return items.fold(0, (sum, item) => sum + (item.calories ?? 0));
  }

  /// Üye mi, hoca mı girmiş?
  bool get isTrainerSuggestion => status == 'trainer_suggestion';
  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get needsRevision => status == 'needs_revision';
}

class DietItem {
  final String? id;
  final String? dietId;
  final String mealName;
  final String content;
  final int? calories;
  final int orderIndex;

  DietItem({
    this.id,
    this.dietId,
    required this.mealName,
    required this.content,
    this.calories,
    required this.orderIndex,
  });

  factory DietItem.fromJson(Map<String, dynamic> json) {
    return DietItem(
      id: json['id'],
      dietId: json['diet_id'],
      mealName: json['meal_name'],
      content: json['content'],
      calories: json['calories'],
      orderIndex: json['order_index'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (dietId != null) 'diet_id': dietId,
      'meal_name': mealName,
      'content': content,
      'calories': calories,
      'order_index': orderIndex,
    };
  }
}
