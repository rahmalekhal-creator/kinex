class Clinic {
  final int id;
  final int accountId;
  final String name;
  final String? address;
  final String? phone;
  final String? justif;

  Clinic({
    required this.id,
    required this.accountId,
    required this.name,
    this.address,
    this.phone,
    this.justif,
  });

  factory Clinic.fromJson(Map<String, dynamic> json) {
    return Clinic(
      id: int.tryParse((json['id'] ?? 0).toString()) ?? 0,
      accountId: int.tryParse((json['account_id'] ?? 0).toString()) ?? 0,
      name: (json['name'] ?? '').toString(),
      address: json['address']?.toString(),
      phone: json['phone']?.toString(),
      justif: json['justif']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'name': name,
      'address': address,
      'phone': phone,
      'justif' : justif
    };
  }

  Clinic copyWith({
    int? id,
    int? accountId,
    String? name,
    String? address,
    String? phone,
    String? justif,
  }) {
    return Clinic(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      justif: justif ?? this.justif
    );
  }

  @override
  String toString() =>
      'Clinic(id: $id, accountId: $accountId, name: $name, phone: $phone, justif : $justif)';
}
