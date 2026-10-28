class Subscription {
  final int id;
  final int clinicId;
  final String? plan;
  final double? amount;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? status;

  Subscription({
    required this.id,
    required this.clinicId,
    this.plan,
    this.amount,
    this.startDate,
    this.endDate,
    this.status,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as int,
      clinicId: json['clinic_id'] as int,
      plan: json['plan'] as String?,
      amount: json['amount'] != null ? (json['amount'] as num).toDouble() : null,
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date'] as String) : null,
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date'] as String) : null,
      status: json['status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clinic_id': clinicId,
      'plan': plan,
      'amount': amount,
      'start_date': startDate?.toIso8601String().split('T').first, // date only
      'end_date': endDate?.toIso8601String().split('T').first,     // date only
      'status': status,
    };
  }

  Subscription copyWith({
    int? id,
    int? clinicId,
    String? plan,
    double? amount,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) {
    return Subscription(
      id: id ?? this.id,
      clinicId: clinicId ?? this.clinicId,
      plan: plan ?? this.plan,
      amount: amount ?? this.amount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
    );
  }

  @override
  String toString() =>
      'Subscription(id: $id, clinicId: $clinicId, plan: $plan, status: $status, amount: $amount)';
}
