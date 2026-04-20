class BadgeModel {
  final String id;
  final String memberId;
  final String badgeType;
  final DateTime earnedAt;
  final bool isSeen;

  const BadgeModel({
    required this.id,
    required this.memberId,
    required this.badgeType,
    required this.earnedAt,
    required this.isSeen,
  });

  factory BadgeModel.fromJson(Map<String, dynamic> json) {
    return BadgeModel(
      id: json['id'] as String,
      memberId: json['member_id'] as String,
      badgeType: json['badge_type'] as String,
      earnedAt: DateTime.parse(json['earned_at'] as String),
      isSeen: (json['is_seen'] as bool?) ?? false,
    );
  }

  BadgeInfo get info => BadgeInfo.fromType(badgeType);
}

class BadgeInfo {
  final String emoji;
  final String title;
  final String description;

  const BadgeInfo({
    required this.emoji,
    required this.title,
    required this.description,
  });

  static BadgeInfo fromType(String type) {
    switch (type) {
      case 'first_class':
        return const BadgeInfo(
          emoji: '🎯',
          title: 'İlk Adım',
          description: 'İlk dersine katıldın!',
        );
      case 'streak_7':
        return const BadgeInfo(
          emoji: '🔥',
          title: 'Demir İrade',
          description: '7 gün üst üste aktif kaldın!',
        );
      case 'streak_30':
        return const BadgeInfo(
          emoji: '⚡',
          title: 'Efsane',
          description: '30 gün üst üste aktif kaldın!',
        );
      case 'water_7':
        return const BadgeInfo(
          emoji: '💧',
          title: 'Su Aşığı',
          description: '7 gün su hedefini tamamladın!',
        );
      case 'first_measurement':
        return const BadgeInfo(
          emoji: '📏',
          title: 'Ölçüm Delikanlısı',
          description: 'İlk ölçümünü girdin!',
        );
      case 'first_diet':
        return const BadgeInfo(
          emoji: '🍽️',
          title: 'Diyet Ustası',
          description: 'İlk diyetini paylaştın!',
        );
      case 'top3_leaderboard':
        return const BadgeInfo(
          emoji: '🏆',
          title: 'Salon Efsanesi',
          description: 'Liderlik tablosunda ilk 3e girdin!',
        );
      default:
        return const BadgeInfo(
          emoji: '⭐',
          title: 'Rozet',
          description: 'Başarı kazandın!',
        );
    }
  }
}

class LeaderboardEntry {
  final String memberId;
  final String displayName;
  final int totalPoints;
  final int rank;
  final bool isCurrentUser;

  const LeaderboardEntry({
    required this.memberId,
    required this.displayName,
    required this.totalPoints,
    required this.rank,
    this.isCurrentUser = false,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json,
      {bool isCurrentUser = false, int rank = 0}) {
    return LeaderboardEntry(
      memberId: json['member_id'] as String,
      displayName: json['display_name'] as String,
      totalPoints: int.tryParse(json['total_points'].toString()) ?? 0,
      rank: rank,
      isCurrentUser: isCurrentUser,
    );
  }
}
