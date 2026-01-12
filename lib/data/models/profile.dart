class Profile {
  final String id;
  final String? firstName;
  final String? lastName;
  final String? profession;
  final int? age;
  final String? hobbies;
  final String? avatarUrl;
  final String? role;
  final DateTime? updatedAt;

  Profile({
    required this.id,
    this.firstName,
    this.lastName,
    this.profession,
    this.age,
    this.hobbies,
    this.avatarUrl,
    this.role,
    this.updatedAt,
  });

  factory Profile.fromSupabase(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] ?? '',
      firstName: map['first_name'],
      lastName: map['last_name'],
      profession: map['profession'],
      age: map['age'],
      hobbies: map['hobbies'],
      avatarUrl: map['avatar_url'],
      role: map['role'],
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at']).toLocal() 
          : null,
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'profession': profession,
      'age': age,
      'hobbies': hobbies,
      'avatar_url': avatarUrl,
      // role is usually not updatable by user here, but if needed:
      // 'role': role, 
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
