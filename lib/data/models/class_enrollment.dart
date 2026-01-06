import 'member.dart';

class ClassEnrollment {
  final String? id;
  final String classId;
  final String memberId;
  final String status; // 'booked', 'attended', 'cancelled'
  final DateTime? createdAt;
  final Member? member; // For joined data

  ClassEnrollment({
    this.id,
    required this.classId,
    required this.memberId,
    this.status = 'booked',
    this.createdAt,
    this.member,
  });

  Map<String, dynamic> toSupabaseMap() {
    return {
      if (id != null) 'id': id,
      'class_id': classId,
      'member_id': memberId,
      'status': status,
    };
  }

  factory ClassEnrollment.fromSupabaseMap(Map<String, dynamic> map) {
    return ClassEnrollment(
      id: map['id'] as String?,
      classId: map['class_id'] as String,
      memberId: map['member_id'] as String,
      status: map['status'] as String? ?? 'booked',
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'] as String).toLocal() 
          : null,
      member: map['members'] != null 
          ? Member.fromSupabaseMap(map['members'] as Map<String, dynamic>) 
          : null,
    );
  }
}
