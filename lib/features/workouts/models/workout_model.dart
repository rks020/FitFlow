import 'exercise_model.dart';

class WorkoutExercise {
  final String id;
  final String workoutId; // Can be null during creation if not saved yet, but DB has it not null. 
                          // In app model, we might treat it as optional or link later.
  final String exerciseId;
  final int orderIndex;
  final int sets;
  final String? reps;
  final int restSeconds;
  final String? notes;
  
  // Optional: Embed the full exercise details for display
  final Exercise? exercise; 

  WorkoutExercise({
    required this.id,
    required this.workoutId,
    required this.exerciseId,
    required this.orderIndex,
    this.sets = 3,
    this.reps,
    this.restSeconds = 60,
    this.notes,
    this.exercise,
  });

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) {
    return WorkoutExercise(
      id: json['id'],
      workoutId: json['workout_id'],
      exerciseId: json['exercise_id'],
      orderIndex: json['order_index'],
      sets: json['sets'],
      reps: json['reps'],
      restSeconds: json['rest_seconds'],
      notes: json['notes'],
      exercise: json['exercises'] != null ? Exercise.fromJson(json['exercises']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workout_id': workoutId,
      'exercise_id': exerciseId,
      'order_index': orderIndex,
      'sets': sets,
      'reps': reps,
      'rest_seconds': restSeconds,
      'notes': notes,
    };
  }
}

class Workout {
  final String id;
  final String organizationId;
  final String name;
  final String? difficulty; // beginner, intermediate, advanced
  final String? description;
  final DateTime createdAt;
  final List<WorkoutExercise> exercises;

  Workout({
    required this.id,
    required this.organizationId,
    required this.name,
    this.difficulty,
    this.description,
    required this.createdAt,
    this.exercises = const [],
  });

  factory Workout.fromJson(Map<String, dynamic> json) {
    var exercisesList = <WorkoutExercise>[];
    if (json['workout_exercises'] != null) {
      exercisesList = (json['workout_exercises'] as List)
          .map((e) => WorkoutExercise.fromJson(e))
          .toList();
      // Sort by order_index
      exercisesList.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    }

    return Workout(
      id: json['id'],
      organizationId: json['organization_id'],
      name: json['name'],
      difficulty: json['difficulty'],
      description: json['description'],
      createdAt: DateTime.parse(json['created_at']),
      exercises: exercisesList,
    );
  }
}
