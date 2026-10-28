class Patient {
  final int id;
  final int accountId;
  final int clinicId;
  final int? therapistId;
  final String name;
  final String? phone;
  final DateTime? birthDate;

  Patient({
    required this.id,
    required this.accountId,
    required this.clinicId,
    this.therapistId,
    required this.name,
    this.phone,
    this.birthDate,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'] as int,
      accountId: json['account_id'] as int,
      clinicId: json['clinic_id'] as int,
      therapistId: json['therapist_id'] as int?,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      birthDate: json['birth_date'] != null ? DateTime.parse(json['birth_date'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'clinic_id': clinicId,
      'therapist_id': therapistId,
      'name': name,
      'phone': phone,
      'birth_date': birthDate?.toIso8601String().split('T').first, // date only
    };
  }

  Patient copyWith({
    int? id,
    int? accountId,
    int? clinicId,
    int? therapistId,
    String? name,
    String? phone,
    DateTime? birthDate,
  }) {
    return Patient(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      clinicId: clinicId ?? this.clinicId,
      therapistId: therapistId ?? this.therapistId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      birthDate: birthDate ?? this.birthDate,
    );
  }

  @override
  String toString() =>
      'Patient(id: $id, name: $name, clinicId: $clinicId, therapistId: $therapistId)';
}
