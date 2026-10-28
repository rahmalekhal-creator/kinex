class PatientExercise {
  final int id;
  final int patientId;
  final int exerciseId;
  final int assignedBy;
  final DateTime? assignedDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? frequency;
  final String? prescriptionId;
  final String? status;
  final String? computedStatus;
  final int sets;
  final int reps;

  PatientExercise({
    required this.id,
    required this.patientId,
    required this.exerciseId,
    required this.assignedBy,
    this.assignedDate,
    this.startDate,
    this.endDate,
    this.frequency,
    this.prescriptionId,
    this.status,
    this.computedStatus,
    required this.sets,
    required this.reps,
  });

  bool get isCompleted {
    final s = (status ?? '').toLowerCase().trim();
    return s == 'completed' || s == 'done';
  }

  bool get isMissed {
    if (isCompleted) return false;
    if (computedStatus == 'missed') return true;
    if (assignedDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final assigned = DateTime(assignedDate!.year, assignedDate!.month, assignedDate!.day);
      return assigned.isBefore(today);
    }
    return false;
  }

  bool get isToday {
    if (assignedDate == null) return false;
    final now = DateTime.now();
    return assignedDate!.year == now.year &&
        assignedDate!.month == now.month &&
        assignedDate!.day == now.day;
  }

  bool get isPending => !isCompleted && !isMissed;

  factory PatientExercise.fromJson(Map<String, dynamic> json) {
    return PatientExercise(
      id: json['id'] as int,
      patientId: json['patient_id'] as int,
      exerciseId: json['exercise_id'] as int,
      assignedBy: json['assigned_by'] as int,
      assignedDate: json['assigned_date'] != null ? DateTime.tryParse(json['assigned_date'] as String) : null,
      startDate: json['start_date'] != null ? DateTime.tryParse(json['start_date'] as String) : null,
      endDate: json['end_date'] != null ? DateTime.tryParse(json['end_date'] as String) : null,
      frequency: json['frequency'] as String?,
      prescriptionId: json['prescription_id'] as String?,
      status: json['status'] as String?,
      computedStatus: json['computed_status'] as String?,
      sets: json['sets'] as int? ?? 1,
      reps: json['reps'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'exercise_id': exerciseId,
      'assigned_by': assignedBy,
      'assigned_date': assignedDate?.toIso8601String().split('T').first,
      'start_date': startDate?.toIso8601String().split('T').first,
      'end_date': endDate?.toIso8601String().split('T').first,
      'frequency': frequency,
      'prescription_id': prescriptionId,
      'status': status,
      'computed_status': computedStatus,
      'sets': sets,
      'reps': reps,
    };
  }

  PatientExercise copyWith({
    int? id,
    int? patientId,
    int? exerciseId,
    int? assignedBy,
    DateTime? assignedDate,
    DateTime? startDate,
    DateTime? endDate,
    String? frequency,
    String? prescriptionId,
    String? status,
    String? computedStatus,
    int? sets,
    int? reps,
  }) {
    return PatientExercise(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      exerciseId: exerciseId ?? this.exerciseId,
      assignedBy: assignedBy ?? this.assignedBy,
      assignedDate: assignedDate ?? this.assignedDate,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      frequency: frequency ?? this.frequency,
      prescriptionId: prescriptionId ?? this.prescriptionId,
      status: status ?? this.status,
      computedStatus: computedStatus ?? this.computedStatus,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
    );
  }

  @override
  String toString() =>
      'PatientExercise(id: $id, patientId: $patientId, exerciseId: $exerciseId, status: $status, sets: $sets, reps: $reps)';
}
