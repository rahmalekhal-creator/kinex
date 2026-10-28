class AiFeedback {
  final int id;
  final int progressId;
  final String? analysis;
  final double? score;
  final DateTime? generatedAt;
  final String? vid_url;

  AiFeedback({
    required this.id,
    required this.progressId,
    this.analysis,
    this.score,
    this.generatedAt,
    this.vid_url,
  });

  factory AiFeedback.fromJson(Map<String, dynamic> json) {
    return AiFeedback(
      id: json['id'] as int,
      progressId: json['progress_id'] as int,
      analysis: json['analysis'] as String?,
      score: json['score'] != null ? (json['score'] as num).toDouble() : null,
      generatedAt: json['generated_at'] != null ? DateTime.parse(json['generated_at'] as String) : null,
      vid_url: json['vid_url'] as String?
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'progress_id': progressId,
      'analysis': analysis,
      'score': score,
      'generated_at': generatedAt?.toIso8601String(),
      'vid_url' : vid_url,
    };
  }

  AiFeedback copyWith({
    int? id,
    int? progressId,
    String? analysis,
    double? score,
    DateTime? generatedAt,
    String? vid_url,
  }) {
    return AiFeedback(
      id: id ?? this.id,
      progressId: progressId ?? this.progressId,
      analysis: analysis ?? this.analysis,
      score: score ?? this.score,
      generatedAt: generatedAt ?? this.generatedAt,
      vid_url: vid_url ?? this.vid_url,
    );
  }

  @override
  String toString() =>
      'AiFeedback(id: $id, progressId: $progressId, score: $score, generatedAt: $generatedAt, vidurl : $vid_url)';
}
