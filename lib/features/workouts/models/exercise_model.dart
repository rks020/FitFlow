class Exercise {
  final String id;
  final String organizationId;
  final String name;
  final String? targetMuscle;
  final String? videoUrl;
  final DateTime createdAt;

  Exercise({
    required this.id,
    required this.organizationId,
    required this.name,
    this.targetMuscle,
    this.videoUrl,
    required this.createdAt,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'],
      organizationId: json['organization_id'],
      name: json['name'],
      targetMuscle: json['target_muscle'],
      videoUrl: json['video_url'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'name': name,
      'target_muscle': targetMuscle,
      'video_url': videoUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
