class ProgressReport {
  final int id;
  final int patientId;
  final int ppId;
  final DateTime? date;
  final String? notes;
  final int? painLevel;
  final int? reps_done;
  ProgressReport({
    required this.id,
    required this.patientId,
    required this.ppId,
    this.date,
    this.notes,
    this.painLevel,
    this.reps_done
  });

  factory ProgressReport.fromJson(Map<String, dynamic> json) {
    return ProgressReport(
      id: json['id'] as int,
      patientId: json['patient_id'] as int,
      ppId: json['ppid'] as int,
      date: json['date'] != null ? DateTime.parse(json['date'] as String) : null,
      notes: json['notes'] as String?,
      painLevel: json['pain_level'] as int?,
        reps_done: json['reps_done'] as int?
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'ppid': ppId,
      'date': date?.toIso8601String(),
      'notes': notes,
      'pain_level': painLevel,
      'reps_done': reps_done,
    };
  }

  ProgressReport copyWith({
    int? id,
    int? patientId,
    int? ppId,
    DateTime? date,
    String? notes,
    int? painLevel,
    int? reps_done,
  }) {
    return ProgressReport(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      ppId: ppId ?? this.ppId,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      painLevel: painLevel ?? this.painLevel,
      reps_done: reps_done ?? this.reps_done,
    );
  }

  @override
  String toString() =>
      'ProgressReport(id: $id, patientId: $patientId, ppId: $ppId, painLevel: $painLevel, date: $date)';
}
