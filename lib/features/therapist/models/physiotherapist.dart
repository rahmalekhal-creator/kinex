class Physiotherapist {
  final int id;
  final int accountId;
  final int clinicId;
  final String name;
  final String? specialization;
  final String? phone;

  Physiotherapist({
    required this.id,
    required this.accountId,
    required this.clinicId,
    required this.name,
    this.specialization,
    this.phone,
  });

  factory Physiotherapist.fromJson(Map<String, dynamic> json) {
    return Physiotherapist(
      id: json['id'] as int,
      accountId: json['account_id'] as int,
      clinicId: json['clinic_id'] as int,
      name: json['name'] as String,
      specialization: json['specialization'] as String?,
      phone: json['phone'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'clinic_id': clinicId,
      'name': name,
      'specialization': specialization,
      'phone': phone,
    };
  }

  Physiotherapist copyWith({
    int? id,
    int? accountId,
    int? clinicId,
    String? name,
    String? specialization,
    String? phone,
  }) {
    return Physiotherapist(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      clinicId: clinicId ?? this.clinicId,
      name: name ?? this.name,
      specialization: specialization ?? this.specialization,
      phone: phone ?? this.phone,
    );
  }

  @override
  String toString() =>
      'Physiotherapist(id: $id, name: $name, clinicId: $clinicId, specialization: $specialization)';
}
