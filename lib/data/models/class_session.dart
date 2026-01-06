class ClassSession {
  final String? id;
  final String title;
  final String? description;
  final String? trainerId;
  final DateTime startTime;
  final DateTime endTime;
  final int capacity;
  final bool isCancelled;
  final DateTime? createdAt;
  
  // Extension for calculating duration
  int get durationMinutes => endTime.difference(startTime).inMinutes;

  ClassSession({
    this.id,
    required this.title,
    this.description,
    this.trainerId,
    required this.startTime,
    required this.endTime,
    this.capacity = 10,
    this.isCancelled = false,
    this.createdAt,
  });

  Map<String, dynamic> toSupabaseMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'description': description,
      'trainer_id': trainerId,
      'start_time': startTime.toUtc().toIso8601String(),
      'end_time': endTime.toUtc().toIso8601String(),
      'capacity': capacity,
      'is_cancelled': isCancelled,
    };
  }

  factory ClassSession.fromSupabaseMap(Map<String, dynamic> map) {
    return ClassSession(
      id: map['id'] as String?,
      title: map['title'] as String,
      description: map['description'] as String?,
      trainerId: map['trainer_id'] as String?,
      startTime: DateTime.parse(map['start_time'] as String).toLocal(),
      endTime: DateTime.parse(map['end_time'] as String).toLocal(),
      capacity: map['capacity'] as int,
      isCancelled: map['is_cancelled'] as bool? ?? false,
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'] as String).toLocal() 
          : null,
    );
  }
}
