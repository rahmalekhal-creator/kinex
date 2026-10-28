class Account {
  final int id;
  final String email;
  final String passwordHash;
  final String role; // enum
  final bool? isActive;
  final DateTime? createdAt;
  final String Photo;

  Account({
    required this.id,
    required this.email,
    required this.passwordHash,
    required this.role,
    this.isActive,
    this.createdAt,
    required this.Photo,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as int,
      email: json['email'] as String,
      passwordHash: json['password_hash'] as String,
      role: json['role'] as String,
      isActive: json['is_active'] != null ? (json['is_active'] == 1 || json['is_active'] == true) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      Photo: json['Photo'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'password_hash': passwordHash,
      'role': role,
      'is_active': isActive == null ? null : (isActive! ? 1 : 0),
      'created_at': createdAt?.toIso8601String(),
      'photo' : Photo
    };
  }

  Account copyWith({
    int? id,
    String? email,
    String? passwordHash,
    String? role,
    bool? isActive,
    DateTime? createdAt,
    String? Photo,
  }) {
    return Account(
      id: id ?? this.id,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      Photo: Photo ?? this.Photo
    );
  }

  @override
  String toString() =>
      'Account(id: $id, email: $email, role: $role, isActive: $isActive, createdAt: $createdAt)';
}
