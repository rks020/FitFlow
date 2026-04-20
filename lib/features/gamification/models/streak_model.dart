class StreakModel {
  final String memberId;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastActivityDate;

  const StreakModel({
    required this.memberId,
    required this.currentStreak,
    required this.longestStreak,
    this.lastActivityDate,
  });

  factory StreakModel.fromJson(Map<String, dynamic> json) {
    return StreakModel(
      memberId: json['member_id'] as String,
      currentStreak: (json['current_streak'] as int?) ?? 0,
      longestStreak: (json['longest_streak'] as int?) ?? 0,
      lastActivityDate: json['last_activity_date'] != null
          ? DateTime.parse(json['last_activity_date'] as String)
          : null,
    );
  }

  factory StreakModel.empty(String memberId) => StreakModel(
        memberId: memberId,
        currentStreak: 0,
        longestStreak: 0,
      );
}
