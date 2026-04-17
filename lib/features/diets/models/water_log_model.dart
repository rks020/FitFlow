class WaterLog {
  final String id;
  final String memberId;
  final int amountMl;
  final DateTime consumedAt;
  final DateTime createdAt;

  WaterLog({
    required this.id,
    required this.memberId,
    required this.amountMl,
    required this.consumedAt,
    required this.createdAt,
  });

  factory WaterLog.fromJson(Map<String, dynamic> json) {
    return WaterLog(
      id: json['id'],
      memberId: json['member_id'],
      amountMl: json['amount_ml'],
      consumedAt: DateTime.parse(json['consumed_at']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'member_id': memberId,
      'amount_ml': amountMl,
      'consumed_at': consumedAt.toIso8601String(),
    };
  }
}
