class ComplaintForm {
  final int id;
  final int patientId;
  final String? description;
  final String? symptoms;
  final DateTime? submittedAt;
  final String? status;

  ComplaintForm({
    required this.id,
    required this.patientId,
    this.description,
    this.symptoms,
    this.submittedAt,
    this.status,
  });

  factory ComplaintForm.fromJson(Map<String, dynamic> json) {
    return ComplaintForm(
      id: json['id'] as int,
      patientId: json['patient_id'] as int,
      description: json['description'] as String?,
      symptoms: json['symptoms'] as String?,
      submittedAt: json['submitted_at'] != null ? DateTime.parse(json['submitted_at'] as String) : null,
      status: json['status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'description': description,
      'symptoms': symptoms,
      'submitted_at': submittedAt?.toIso8601String(),
      'status': status,
    };
  }

  ComplaintForm copyWith({
    int? id,
    int? patientId,
    String? description,
    String? symptoms,
    DateTime? submittedAt,
    String? status,
  }) {
    return ComplaintForm(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      description: description ?? this.description,
      symptoms: symptoms ?? this.symptoms,
      submittedAt: submittedAt ?? this.submittedAt,
      status: status ?? this.status,
    );
  }

  @override
  String toString() =>
      'ComplaintForm(id: $id, patientId: $patientId, status: $status, submittedAt: $submittedAt)';
}
