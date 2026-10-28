class Exercise {
  final int id;
  final int therapistId;
  final String name;
  final String? description;
  final String? videoUrl;
  final String? difficulty;
  Exercise({
    required this.id,
    required this.therapistId,
    required this.name,
    this.description,
    this.videoUrl,
    this.difficulty,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as int,
      therapistId: json['therapist_id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      videoUrl: json['video_url'] as String?,
      difficulty: json['difficulty'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'therapist_id': therapistId,
      'name': name,
      'description': description,
      'video_url': videoUrl,
      'difficulty': difficulty,
    };
  }

  Exercise copyWith({
    int? id,
    int? therapistId,
    String? name,
    String? description,
    String? videoUrl,
    String? difficulty,
  }) {
    return Exercise(
      id: id ?? this.id,
      therapistId: therapistId ?? this.therapistId,
      name: name ?? this.name,
      description: description ?? this.description,
      videoUrl: videoUrl ?? this.videoUrl,
      difficulty: difficulty ?? this.difficulty,
    );
  }

  @override
  String toString() =>
      'Exercise(id: $id, therapistId: $therapistId, name: $name, difficulty: $difficulty)';
}
